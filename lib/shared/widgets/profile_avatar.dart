import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/users/domain/profile.dart';

/// Circular avatar with network image support and an initials fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.profile, this.url, this.radius = 24});

  /// Either a [profile] (uses its avatarUrl/initials) or an explicit [url].
  final Profile? profile;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedUrl = url ?? profile?.avatarUrl;
    final hasImage = resolvedUrl != null && resolvedUrl.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage: hasImage
          ? CachedNetworkImageProvider(
              resolvedUrl,
              maxWidth: (radius * 2).round(),
            )
          : null,
      child: hasImage
          ? null
          : Text(
              profile?.initials ?? '?',
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600),
            ),
    );
  }
}
