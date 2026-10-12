import 'package:flutter/material.dart';

import '../../../core/utils/time_format.dart';
import '../domain/message.dart';

/// A single chat bubble (own vs. other styling, time, read receipt).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showTail = true,
  });

  final Message message;
  final bool isMine;

  /// Whether this bubble is the last of a consecutive run (draws the tail).
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(showTail && isMine ? 18 : 4),
      bottomRight: Radius.circular(showTail && !isMine ? 18 : 4),
    );

    final bg = isMine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = isMine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMine ? 64 : 12,
          right: isMine ? 12 : 64,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message.content,
                  width: 220,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: 220,
                          height: 150,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 220,
                    height: 60,
                    child: Center(child: Text('Image unavailable')),
                  ),
                ),
              )
            else
              Text(
                message.content,
                style: TextStyle(color: fg, height: 1.3),
              ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TimeFormat.messageTime(message.createdAt),
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? const Color(0xFF7DD3FC)
                        : fg.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
