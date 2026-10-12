import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Broadcast-based typing indicator for one conversation.
///
/// Each side of the conversation joins a channel keyed by the conversation
/// id and broadcasts a lightweight `typing` ping while the composer has
/// text. The exposed state is the time of the *other* user's last ping,
/// which the UI converts into "… is typing" for a few seconds.
class TypingWatcher {
  TypingWatcher(this._client, this.conversationId, this.selfId) {
    _channel = _client
        .channel('typing:$conversationId')
        .onBroadcast(event: typingEvent, callback: _onPayload)
        .subscribe();
  }

  static const typingEvent = 'typing';
  static const _expiry = Duration(seconds: 4);

  final SupabaseClient _client;
  final String conversationId;
  final String selfId;

  late final RealtimeChannel _channel;
  final _controller = StreamController<DateTime?>.broadcast();
  Timer? _expiryTimer;

  /// Emits the timestamp of the other user's latest typing ping, or null
  /// when the indicator expires.
  Stream<DateTime?> get events => _controller.stream;

  void _onPayload(Map<String, dynamic> payload) {
    // The callback receives the broadcast envelope: `{'event': ...,
    // 'payload': <what we sent>}`, so the data lives under 'payload'.
    final data = payload['payload'];
    if (data is Map && data['sender_id'] == selfId) return; // ignore own pings
    _controller.add(DateTime.now());
    _expiryTimer?.cancel();
    _expiryTimer = Timer(_expiry, () => _controller.add(null));
  }

  /// Call on each composer change (throttled by the caller).
  Future<void> ping() async {
    await _channel.sendBroadcastMessage(
      event: typingEvent,
      payload: {'sender_id': selfId},
    );
  }

  void dispose() {
    _expiryTimer?.cancel();
    _controller.close();
    _client.removeChannel(_channel);
  }
}

