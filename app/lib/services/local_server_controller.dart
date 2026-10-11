/// 플랫폼별 구현을 고른다 — 네이티브(Android/Windows)에서는 실제 내장
/// Dart 서버를, 웹에서는 "지원 안 됨"으로 동작하는 스텁을 쓴다. 둘 다
/// package:sqlite3/shelf처럼 웹에서 컴파일되지 않는 코드에 의존하기
/// 때문에 꼭 이렇게 분리해야 한다.
library;

export 'local_server_controller_stub.dart' if (dart.library.io) 'local_server_controller_io.dart';
