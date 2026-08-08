import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _discoveryPort = 41234;
const _magicRequest = 'FAMIL_APP_DISCOVER';

/// backend/src/discovery.js와 동일한 UDP 탐색 프로토콜에 응답한다. 이 기기가
/// 백업 서버로 동작 중일 때, 같은 Wi-Fi의 다른 기기가 기존 "자동 감지" 기능으로
/// 그대로 이 기기를 찾을 수 있게 해준다 — 별도의 클라이언트 변경이 필요 없다.
Future<RawDatagramSocket> startUdpDiscoveryResponder(int httpPort) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
  socket.broadcastEnabled = true;

  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null) return;
    if (utf8.decode(datagram.data) != _magicRequest) return;
    final reply = utf8.encode(json.encode({'service': 'famil-app', 'port': httpPort}));
    socket.send(reply, datagram.address, datagram.port);
  });

  return socket;
}
