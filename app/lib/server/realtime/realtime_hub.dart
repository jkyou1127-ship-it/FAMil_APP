import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/serialize.dart';

typedef RealtimeEventHandler = void Function(
  int userId,
  Map<String, dynamic> data,
  void Function(Map<String, dynamic>) ack,
);

/// backend/src/sockets/index.js + sockets/io.js를 하나로 합친 실시간 계층.
/// Socket.IO를 대체하는 순수 WebSocket + JSON 이벤트 봉투(`{event, data}`)
/// 프로토콜을 쓴다 (Dart로 유지보수 가능한 Socket.IO 서버 구현체가 없기 때문).
class RealtimeHub {
  final Database db;
  RealtimeHub(this.db);

  final Map<int, Set<WebSocketChannel>> _connections = {};
  final Map<String, RealtimeEventHandler> _eventHandlers = {};

  /// 클라이언트가 보내는 이벤트(예: `message:send`)에 대한 핸들러를 등록한다.
  /// 라우트 모듈이 자신의 이벤트를 여기 등록해 실제 비즈니스 로직을 갖는다.
  void on(String event, RealtimeEventHandler handler) {
    _eventHandlers[event] = handler;
  }

  bool get hasConnections => _connections.isNotEmpty;

  void handleConnection(int userId, WebSocketChannel channel) {
    _connections.putIfAbsent(userId, () => {}).add(channel);
    db.execute('UPDATE users SET online = 1 WHERE id = ?', [userId]);
    broadcastStatus();

    channel.stream.listen(
      (raw) => _handleIncoming(userId, channel, raw),
      onDone: () => _handleDisconnect(userId, channel),
      onError: (_) => _handleDisconnect(userId, channel),
      cancelOnError: true,
    );
  }

  void _handleIncoming(int userId, WebSocketChannel channel, dynamic raw) {
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
    final ackId = message['ackId'];

    final handler = _eventHandlers[event];
    if (handler == null) return;
    handler(
      userId,
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
      (ackData) {
        if (ackId == null) return;
        channel.sink.add(json.encode({'event': 'ack', 'ackId': ackId, 'data': ackData}));
      },
    );
  }

  void _handleDisconnect(int userId, WebSocketChannel channel) {
    final set = _connections[userId];
    set?.remove(channel);
    if (set != null && set.isEmpty) {
      _connections.remove(userId);
      db.execute('UPDATE users SET online = 0 WHERE id = ?', [userId]);
      broadcastStatus();
    }
  }

  void emitToUser(int userId, String event, Object? data) {
    final set = _connections[userId];
    if (set == null || set.isEmpty) return;
    final payload = json.encode({'event': event, 'data': data});
    for (final channel in set) {
      channel.sink.add(payload);
    }
  }

  void broadcast(String event, Object? data) {
    final payload = json.encode({'event': event, 'data': data});
    for (final set in _connections.values) {
      for (final channel in set) {
        channel.sink.add(payload);
      }
    }
  }

  void broadcastStatus() {
    final users = db.select('SELECT * FROM users ORDER BY id').map(publicUser).toList();
    broadcast('status:update', {'users': users});
  }

  void broadcastRooms() {
    final rooms = db.select('SELECT * FROM rooms ORDER BY id').map(publicRoom).toList();
    broadcast('rooms:update', {'rooms': rooms});
  }
}
