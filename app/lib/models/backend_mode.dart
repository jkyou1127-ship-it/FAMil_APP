/// local: 같은 Wi-Fi의 PC/폰이 돌리는 서버(Node 또는 Dart)에 연결된 상태.
/// firebase: 로컬 서버에 연결할 수 없을 때(PC가 꺼져 있거나 다른 네트워크에
/// 있을 때) 쓰는 대체 경로. 로그인/상태창/1:1 매신저만 지원하고, 나머지
/// 기능은 "Firebase 모드에서는 지원되지 않습니다" 오류로 안내한다.
enum BackendMode { local, firebase }
