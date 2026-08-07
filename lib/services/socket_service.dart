import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as socket_io;

/// server/(자체 백엔드)의 Socket.io 실시간 이벤트를 구독한다.
/// 리포지토리들은 이 서비스의 이벤트 스트림을 구독해 "무언가 바뀌었으니
/// REST로 다시 불러오라"는 신호로 사용한다 (fine-grained diff 대신
/// invalidate-and-refetch 전략).
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  socket_io.Socket? _socket;
  final _controller = StreamController<String>.broadcast();

  void connect({required String baseUrl, required String token}) {
    disconnect();
    _socket = socket_io.io(
      baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.onAny((event, data) => _controller.add(event));
    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  /// [event]가 발생할 때마다 알려주는 스트림.
  Stream<void> events(String event) =>
      _controller.stream.where((e) => e == event).map((_) {});
}
