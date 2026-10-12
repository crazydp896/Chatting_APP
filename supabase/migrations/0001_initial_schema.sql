-- =============================================================
-- Chat App — initial schema, RLS, RPC and realtime setup
-- Run this whole file in the Supabase SQL Editor (or via CLI).
-- =============================================================

-- ---------- 1. PROFILES --------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null unique check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  full_name   text check (full_name is null or char_length(full_name) <= 60),
  avatar_url  text,
  last_seen   timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

comment on table public.profiles is 'Public-facing user profiles, 1:1 with auth.users.';

-- Auto-create a profile whenever an auth user is created.
-- username comes from signup metadata, falling back to the email local-part.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_username text;
  final_username text;
begin
  base_username := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    split_part(coalesce(new.email, new.id::text), '@', 1)
  );
  base_username := regexp_replace(base_username, '[^A-Za-z0-9_]', '', 'g');
  base_username := left(coalesce(base_username, 'user'), 24);

  if char_length(base_username) < 3 then
    base_username := left(base_username || '_' || substr(new.id::text, 1, 6), 24);
  end if;

  final_username := base_username;
  while exists (select 1 from public.profiles p where p.username = final_username) loop
    final_username := left(base_username, 18) || '_' || floor(random() * 900000 + 100000)::text;
  end loop;

  insert into public.profiles (id, username, full_name)
  values (new.id, final_username, nullif(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 2. CONVERSATIONS ---------------------------------
create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  -- Canonical ordering: user_a < user_b guarantees one row per pair.
  user_a_id       uuid not null references public.profiles (id) on delete cascade,
  user_b_id       uuid not null references public.profiles (id) on delete cascade,
  last_message_at timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  constraint conversations_pair_unique unique (user_a_id, user_b_id),
  constraint conversations_pair_ordered check (user_a_id < user_b_id)
);

create index if not exists conversations_user_a_idx on public.conversations (user_a_id);
create index if not exists conversations_user_b_idx on public.conversations (user_b_id);

-- ---------- 3. MESSAGES --------------------------------------
create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references public.profiles (id) on delete cascade,
  content         text not null check (char_length(content) between 1 and 4000),
  type            text not null default 'text' check (type in ('text', 'image')),
  created_at      timestamptz not null default now(),
  read_at         timestamptz
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);

-- Keep conversation ordering fresh when a message is sent.
create or replace function public.bump_conversation_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations
     set last_message_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists on_message_created on public.messages;
create trigger on_message_created
  after insert on public.messages
  for each row execute function public.bump_conversation_activity();

-- ---------- 4. RPC: get_or_create_conversation ----------------
-- Returns the summary-view row between the caller and `other_user_id`,
-- creating the conversation if it does not exist yet.
create or replace function public.get_or_create_conversation(other_user_id uuid)
returns table (
  id uuid,
  user_a_id uuid,
  user_b_id uuid,
  last_message_at timestamptz,
  created_at timestamptz,
  other_user jsonb,
  last_message jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  conv_id uuid;
  a uuid;
  b uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if me = other_user_id then
    raise exception 'cannot open a conversation with yourself';
  end if;
  if not exists (select 1 from public.profiles p where p.id = other_user_id) then
    raise exception 'target user not found';
  end if;

  if me < other_user_id then a := me; b := other_user_id;
  else a := other_user_id; b := me; end if;

  insert into public.conversations (user_a_id, user_b_id)
  values (a, b)
  on conflict (user_a_id, user_b_id) do nothing;

  select c.id into conv_id
    from public.conversations c
   where c.user_a_id = a and c.user_b_id = b;

  return query
    select * from public.conversation_summaries s
     where s.id = conv_id;
end;
$$;

-- ---------- 5. SUMMARY VIEW (chats-list screen) ---------------
create or replace view public.conversation_summaries
with (security_invoker = on) as
select
  c.id,
  c.user_a_id,
  c.user_b_id,
  c.last_message_at,
  c.created_at,
  to_jsonb(p.*) as other_user,
  (
    select to_jsonb(m.*)
      from public.messages m
     where m.conversation_id = c.id
     order by m.created_at desc
     limit 1
  ) as last_message
from public.conversations c
join public.profiles p
  on p.id = case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end
where auth.uid() in (c.user_a_id, c.user_b_id);

-- ---------- 6. ROW LEVEL SECURITY ----------------------------
alter table public.profiles      enable row level security;
alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
  for select to authenticated
  using (auth.uid() in (user_a_id, user_b_id));

drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert on public.conversations
  for insert to authenticated
  with check (auth.uid() in (user_a_id, user_b_id) and user_a_id < user_b_id);

drop policy if exists conversations_update on public.conversations;
create policy conversations_update on public.conversations
  for update to authenticated
  using (auth.uid() in (user_a_id, user_b_id))
  with check (auth.uid() in (user_a_id, user_b_id));

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and auth.uid() in (c.user_a_id, c.user_b_id)
  ));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
       where c.id = conversation_id
         and auth.uid() in (c.user_a_id, c.user_b_id)
    )
  );

drop policy if exists messages_update on public.messages;
create policy messages_update on public.messages
  for update to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and auth.uid() in (c.user_a_id, c.user_b_id)
  ))
  with check (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and auth.uid() in (c.user_a_id, c.user_b_id)
  ));

-- ---------- 7. REALTIME --------------------------------------
-- Full row images so payload filters and callbacks receive all columns.
alter table public.messages replica identity full;
alter table public.conversations replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.conversations;
exception when duplicate_object then null;
end $$;

-- ---------- 8. STORAGE: avatars + chat images -----------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('chat_images', 'chat_images', true)
on conflict (id) do nothing;

drop policy if exists "avatar_public_read" on storage.objects;
create policy "avatar_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatar_owner_write" on storage.objects;
create policy "avatar_owner_write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "avatar_owner_delete" on storage.objects;
create policy "avatar_owner_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "chat_images_read" on storage.objects;
create policy "chat_images_read" on storage.objects
  for select to authenticated using (bucket_id = 'chat_images');

drop policy if exists "chat_images_write" on storage.objects;
create policy "chat_images_write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat_images' and owner = auth.uid());




