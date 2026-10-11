/// 플랫폼별 구현을 고른다 — 네이티브(Android/Windows)에서는 실제 UDP
/// 브로드캐스트 탐색을, 웹에서는 늘 "찾지 못함"을 반환하는 스텁을 쓴다.
library;

export 'server_discovery_service_stub.dart' if (dart.library.io) 'server_discovery_service_io.dart';
