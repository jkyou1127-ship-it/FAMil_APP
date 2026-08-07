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
          .setTransports(['websocket'])
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
