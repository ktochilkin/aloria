import 'dart:async';
import 'dart:convert';

import 'package:aloria/core/env/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class RealtimeClient {
  Future<void> ensureConnected();
  Stream<Map<String, dynamic>> get stream;
  void send(Map<String, dynamic> message);
  Future<void> close();
}

class WebSocketRealtimeClient implements RealtimeClient {
  WebSocketRealtimeClient({required this.url});

  final Uri url;
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Future<void>? _pendingConnect;

  @override
  Future<void> ensureConnected() {
    if (_pendingConnect != null) return _pendingConnect!;
    _pendingConnect = Future<void>(() {
      _channel = WebSocketChannel.connect(url);
      _channel!.stream.listen(
        _handleEvent,
        onError: _controller.addError,
        onDone: () {
          _channel = null;
          _pendingConnect = null;
          _controller.add({'__ws_closed': true});
        },
      );
    });
    return _pendingConnect!;
  }

  void _handleEvent(dynamic raw) {
    try {
      final decoded = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : (raw as Map).cast<String, dynamic>();
      _controller.add(decoded);
    } catch (_) {
      // Drop malformed messages silently.
    }
  }

  @override
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  @override
  void send(Map<String, dynamic> message) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    await _channel?.sink.close(ws_status.normalClosure);
    await _controller.close();
    _pendingConnect = null;
  }
}

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = WebSocketRealtimeClient(url: Uri.parse(config.wsBaseUrl));
  ref.onDispose(client.close);
  return client;
});

// Dedicated WS client for background/portfolio streams.
final portfolioRealtimeClientProvider = Provider<RealtimeClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = WebSocketRealtimeClient(url: Uri.parse(config.wsBaseUrl));
  ref.onDispose(client.close);
  return client;
});

// Separate WS client for trading (quotes/order book), so UI tab swaps
// don't impact portfolio subscription state.
final tradingRealtimeClientProvider = Provider<RealtimeClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = WebSocketRealtimeClient(url: Uri.parse(config.wsBaseUrl));
  ref.onDispose(client.close);
  return client;
});
