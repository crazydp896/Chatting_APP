import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_providers.dart';

/// Uploads avatars and chat images to Supabase Storage.
class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;

  static const avatarsBucket = 'avatars';
  static const chatImagesBucket = 'chat_images';

  /// Uploads [file] to [bucket] under a unique name; returns the public URL.
  Future<String> uploadImage({
    required File file,
    required String bucket,
    required String ownerId,
  }) async {
    final dot = file.path.lastIndexOf('.');
    final extension =
        dot == -1 ? 'jpg' : file.path.substring(dot + 1).toLowerCase();
    final name =
        '${ownerId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$bucket/$name';

    await _client.storage.from(bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> uploadAvatar({required File file, required String ownerId}) =>
      uploadImage(file: file, bucket: avatarsBucket, ownerId: ownerId);

  Future<String> uploadChatImage({required File file, required String ownerId}) =>
      uploadImage(file: file, bucket: chatImagesBucket, ownerId: ownerId);
}

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(supabaseProvider));
});
