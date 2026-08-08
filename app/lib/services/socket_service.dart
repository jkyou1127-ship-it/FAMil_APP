import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

/// 실시간 연결을 감싸는 얇은 래퍼. 온라인 노크, 실시간 매신저, 상태창
/// 등 서버가 즉시 밀어주는 이벤트를 수신하는 데 사용한다.
///
/// Socket.IO 대신 raw WebSocket + JSON 이벤트 봉투(`{event, data[, ackId]}`)를
/// 쓴다 — Node/Dart 두 백엔드가 같은 프로토콜을 쓰기 때문에, 클라이언트는
/// 어느 쪽에 연결되어 있는지 신경 쓸 필요가 없다.
class SocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  final _random = Random();

  String? _baseUrl;
  String? _token;
  bool _manuallyDisconnected = true;
  int _reconnectAttempt = 0;

  bool get isConnected => _channel != null;

  final Map<String, List<void Function(dynamic)>> _handlers = {};
  final Map<String, void Function(dynamic)> _ackCallbacks = {};

  void connect(String baseUrl, String token) {
    disconnect();
    _manuallyDisconnected = false;
    _baseUrl = baseUrl;
    _token = token;
    _reconnectAttempt = 0;
    _open();
  }

  void _open() {
    final base = _baseUrl;
    final token = _token;
    if (base == null || token == null) return;

    final httpUri = Uri.parse(base);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = httpUri.replace(scheme: wsScheme, path: '/realtime', queryParameters: {'token': token});

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleRaw,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleRaw(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> message;
    try {
      message = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final event = message['event'];
    if (event is! String) return;
    final data = message['data'];

    if (event == 'ack') {
      final ackId = message['ackId'];
      final callback = ackId is String ? _ackCallbacks.remove(ackId) : null;
      callback?.call(data);
      return;
    }

    final handlers = _handlers[event];
    if (handlers == null) return;
    for (final handler in List.of(handlers)) {
      handler(data);
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    if (!_manuallyDisconnected) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempt = min(_reconnectAttempt + 1, 6);
    final delaySeconds = min(30, pow(2, _reconnectAttempt).toInt()) + _random.nextInt(2);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_manuallyDisconnected) _open();
    });
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _ackCallbacks.clear();
  }

  void on(String event, void Function(dynamic) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, [void Function(dynamic)? handler]) {
    if (handler == null) {
      _handlers.remove(event);
      return;
    }
    _handlers[event]?.remove(handler);
  }

  void emit(String event, dynamic data, [void Function(dynamic)? ack]) {
    final channel = _channel;
    if (channel == null) return;

    final message = <String, dynamic>{'event': event, 'data': data};
    if (ack != null) {
      final ackId = '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
      _ackCallbacks[ackId] = ack;
      message['ackId'] = ackId;
    }
    channel.sink.add(json.encode(message));
  }
}
