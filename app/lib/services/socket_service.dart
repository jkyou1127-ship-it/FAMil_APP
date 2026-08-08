import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.IO 연결을 감싸는 얇은 래퍼. 온라인 노크, 실시간 매신저, 상태창,
/// 추첨 결과 등 서버가 즉시 밀어주는 이벤트를 수신하는 데 사용한다.
class SocketService {
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String baseUrl, String token) {
    disconnect();
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          // websocket을 우선 시도하되, 방화벽/프록시 등으로 업그레이드가 막히는
          // 환경(예: PC를 서버로 쓸 때 LAN 너머 연결)에서도 polling으로 폴백해
          // 연결이 끊기지 않도록 한다.
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, void Function(dynamic) handler) => _socket?.on(event, handler);

  void off(String event, [void Function(dynamic)? handler]) => _socket?.off(event, handler);

  void emit(String event, dynamic data, [void Function(dynamic)? ack]) {
    if (ack != null) {
      _socket?.emitWithAck(event, data, ack: ack);
    } else {
      _socket?.emit(event, data);
    }
  }
}
