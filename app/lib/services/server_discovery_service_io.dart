import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 같은 Wi-Fi 안에서 UDP 브로드캐스트로 FAMil APP 백엔드를 찾는다.
/// PC의 IP를 직접 입력하지 않아도 서버 주소를 자동으로 채워 넣을 수 있다.
class ServerDiscoveryService {
  static const _port = 41234;
  static const _magic = 'FAMIL_APP_DISCOVER';

  /// 응답이 오면 `http://ip:port` 형태의 서버 주소를, 시간 안에 못 찾으면 null을 반환한다.
  static Future<String?> discover({Duration timeout = const Duration(seconds: 3)}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final completer = Completer<String?>();

      final subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;
        try {
          final data = json.decode(utf8.decode(datagram.data)) as Map<String, dynamic>;
          if (data['service'] == 'famil-app' && data['port'] != null && !completer.isCompleted) {
            completer.complete('http://${datagram.address.address}:${data['port']}');
          }
        } catch (_) {
          // 다른 브로드캐스트 트래픽은 무시한다.
        }
      });

      socket.send(utf8.encode(_magic), InternetAddress('255.255.255.255'), _port);

      final result = await completer.future.timeout(timeout, onTimeout: () => null);
      await subscription.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }
}
