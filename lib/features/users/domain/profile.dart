/// A user profile row (`public.profiles`), joined to `auth.users`.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.lastSeen,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? lastSeen;
  final DateTime createdAt;

  /// Name to show in UI: full name if present, otherwise username.
  String get displayName => (fullName == null || fullName!.trim().isEmpty) ? username : fullName!;

  /// Up to two uppercase initials for the avatar fallback circle.
  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        username: map['username'] as String,
        fullName: map['full_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        lastSeen: map['last_seen'] == null ? null : DateTime.parse(map['last_seen'] as String).toLocal(),
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };
}
