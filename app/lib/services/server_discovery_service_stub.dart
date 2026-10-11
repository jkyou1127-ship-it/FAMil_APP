/// 웹에서는 UDP 브로드캐스트를 쓸 수 없어 같은 Wi-Fi 자동 감지를 지원하지
/// 않는다 — 네이티브(Android/Windows) 구현은 server_discovery_service_io.dart에 있다.
class ServerDiscoveryService {
  static Future<String?> discover({Duration timeout = const Duration(seconds: 3)}) async => null;
}
