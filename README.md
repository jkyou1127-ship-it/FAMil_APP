# 패밀 (FAMil) — 룸메이트 관리 앱

온라인 노크, 매신저, 상태창, 추첨, 취침/기상, 알람, 일정, 할 일 목록 등을 제공하는
룸메이트 관리 앱입니다. Flutter 하나의 코드베이스로 **Android APK**와 **Windows 데스크톱(PC)**
앱을 모두 빌드하며, 로그인과 실시간 데이터는 Google/Firebase 등 외부 서비스 없이 **`server/`에
포함된 자체 백엔드(Node.js)** 가 전담합니다. 모든 시각 정보는 기기 시간대와 무관하게
**한국 표준시(KST, UTC+9)** 기준으로 계산·표시됩니다.

## 구현된 기능

- **로그인/회원가입** (이메일·비밀번호, 앱 자체 계정 — 외부 계정 불필요), **첫 번째 가입 계정 =
  관리자 자동 지정**
- **관리자 화면**: 방 생성/삭제, 방에 소유자 배정·해제
- **실시간 KST 시계**
- **상태창**: 프로필(이니셜 아바타), 출입 가능/불가 표시, 온라인/오프라인, 취침 여부, 오늘 일정 아이콘
- **온라인 노크**: 방을 클릭 → 소유자에게 실시간 알림 → 소유자 승인/거절 → 요청자에게 알림
- **온라인 출입 가능/불가능 변경**: 소유자가 상태창에서 토글하면 해당 방의 노크 기능이 즉시 비활성화됨
- **온라인 매신저**: 1:1 실시간 채팅, 대화 목록/안읽음 표시
- **건의사항**: 익명 등록(작성자 정보 저장 안 함), 전체 공개 목록
- **추첨 시스템**: 참가자를 선택해 그중 한 명을 무작위로 뽑고 이력 저장
- **취침과 기상 시스템**: 취침 클릭 시 시각 기록 + 수면유도 노래 재생(재생 시간 지정, on/off 설정은
  다시 켜기 전까지 유지), 기상 클릭 시 잔 시간 계산·기록
- **알람 시스템**: 매일/요일별/날짜 지정 반복, 내장 알람음 3종 또는 기기에서 직접 선택한 음원,
  울릴 때 전체화면 + "알람 끄기"로 소리 중단
- **할 일 목록**: 등록/완료(취소선+회색 처리)/삭제, 완료된 지 하루(한국 날짜 기준)가 지나면 자동 삭제
- **일정 시스템**: 날짜별 일정 등록, 상태창에 오늘 일정 표시

## 아키텍처

```
famil_app/
  server/   ← 자체 백엔드 (Node.js + Express + SQLite + Socket.io). 어디든 직접 호스팅.
  lib/      ← Flutter 앱 (Android APK + Windows 데스크톱). server/의 REST API·소켓에 접속.
```

- **로그인**: 이메일/비밀번호를 서버에 직접 등록하는 앱 자체 계정입니다. Google/Firebase 등
  외부 로그인이 전혀 필요 없습니다. 비밀번호는 서버에 bcrypt로 해시되어 저장되고, 로그인 시
  JWT 토큰을 발급받아 기기에 저장합니다.
- **실시간 동기화**: Socket.io로 "무언가 바뀌었다"는 신호를 받으면 해당 데이터를 REST로 다시
  불러오는 방식입니다(온라인 노크, 매신저, 상태창, 건의함 등).
- **데이터 저장**: SQLite 파일 하나(`server/data/famil.db`)에 전부 저장됩니다. 별도 데이터베이스
  서버가 필요 없어 어디에든 가볍게 배포할 수 있습니다.

## 기술 스택

**서버** (`server/`): Node.js(ESM) · Express · better-sqlite3 · jsonwebtoken · bcryptjs · Socket.io

**앱** (`lib/`): Flutter 3.44 (stable) · http/socket_io_client(자체 서버 연동) · shared_preferences
(서버 주소·로그인 토큰 저장) · provider(세션 상태) · audioplayers(알람·수면유도 음악) ·
flutter_local_notifications+timezone(Android 알람 보조 알림) · file_picker(알람음 직접 선택)

> Windows 데스크톱 빌드는 순수 Flutter/Dart 플러그인만 사용하므로 외부 SDK 제약이 없습니다.
> **Linux 데스크톱은 스캐폴딩에서 제외했습니다** (Android/Windows만 요청 범위였음).
> (macOS/iOS도 요청 범위에 없어 스캐폴딩하지 않았습니다. 필요하면
> `flutter create --platforms=ios,macos .`로 추가할 수 있습니다.)

## 알람 시스템 동작 방식 (중요)

알람은 두 겹으로 동작합니다.

1. **앱 내부 알람 엔진** (`lib/screens/home/home_shell.dart`): 앱이 실행 중일 때 1초마다 현재
   KST 시각과 등록된 알람을 비교합니다. 일치하면 알람음을 반복 재생하고 전체화면 알람창을 띄우며,
   "알람 끄기"를 눌러야 소리가 멈추고 창이 닫힙니다. Android/Windows 모두에서 동일하게 동작합니다.
2. **Android 전용 백그라운드 보조 알림** (`lib/services/alarm_notification_service.dart`):
   `flutter_local_notifications`로 정확한 시각에 시스템 알림을 예약합니다. 앱이 백그라운드에
   있거나 완전히 종료된 상태에서도 사용자에게 알려주기 위한 보조 수단입니다. 단, 이 알림은
   내장/커스텀 알람음이 아닌 기본 알림음을 사용합니다. **Windows는 flutter_local_notifications가
   공식 지원하지 않으므로, Windows에서는 앱이 실행 중일 때만 알람이 울립니다.**
3. Android 12+ 에서는 "정확한 알람" 권한을 사용자가 직접 허용해야 할 수 있습니다(앱 최초 실행 시
   자동으로 권한을 요청합니다).

## 알람/수면유도 사운드

`assets/sounds/`에 들어있는 4개의 wav 파일은 외부 음원이 아니라 `tools/generate_sounds.py`
스크립트로 사인파를 합성해 직접 만든 것입니다(저작권 문제 없음). 다시 생성하거나 다른 멜로디로
바꾸려면:

```bash
python3 tools/generate_sounds.py
```

- `sleep_calm.wav` — 수면유도용 잔잔한 화음 루프
- `alarm_classic.wav` / `alarm_melody1.wav` / `alarm_melody2.wav` — 알람음 3종

## 시작하기

### 1. 서버 실행

```bash
cd server
npm install
cp .env.example .env   # JWT_SECRET을 무작위 문자열로 바꿔주세요
npm start               # http://localhost:8080 에서 실행
```

개발 중 자동 재시작이 필요하면 `npm run dev`를 사용하세요. 데이터는 `server/data/famil.db`
SQLite 파일 하나에 저장됩니다(백업하려면 이 파일만 복사하면 됩니다).

**어디에 배포하나요?** 룸메이트들이 접속할 수 있는 아무 곳이면 됩니다 — 집 안 공유기에 물린
소형 서버/라즈베리파이, 클라우드 VPS, 또는 `server/Dockerfile`로 컨테이너 배포도 가능합니다.

```bash
cd server
docker build -t famil-server .
docker run -p 8080:8080 -e JWT_SECRET=여기에_무작위_문자열 -v famil-data:/app/data famil-server
```

모바일 기기에서 접속하려면 서버가 **기기에서 도달 가능한 주소**(사설 IP, 도메인 등)로 열려
있어야 합니다. `http://localhost:8080`은 데스크톱에서 서버와 앱을 같은 PC에서 실행할 때만
유효합니다.

### 2. 앱 실행

```bash
flutter pub get
flutter run              # 연결된 기기/에뮬레이터에서 실행
flutter run -d windows   # Windows 데스크톱
```

앱을 처음 실행하면 **서버 주소 입력 화면**이 나옵니다(예: `http://192.168.0.10:8080`). 한 번
입력하면 기기에 저장되어 다음부터는 바로 로그인 화면으로 이동합니다. 로그인 화면 하단의
"서버 주소 변경"으로 언제든 다시 바꿀 수 있습니다.

### 3. 빌드

```bash
flutter build apk --release       # Android APK (build/app/outputs/flutter-apk/)
flutter build windows --release   # Windows 실행 파일 (build/windows/x64/runner/Release/)
```

Android SDK/Windows 빌드 도구가 없는 환경(예: 이 저장소를 만든 CI 컨테이너)에서는 로컬 빌드가
불가능하므로, `.github/workflows/build.yml`에 GitHub Actions 워크플로를 포함했습니다. 저장소를
GitHub에 push하면 자동으로 (1) 백엔드 테스트, (2) `flutter analyze`/`flutter test`,
(3) Android APK, (4) Windows 실행 파일을 빌드하고 Actions 실행 결과의 Artifacts에서 내려받을
수 있습니다.

## 데이터 모델 (server/, SQLite)

| 테이블 | 설명 |
|---|---|
| `users` | 이메일/비밀번호 해시, 이름, 권한(admin/member), 배정된 room_id, 온라인 여부, 출입 가능 여부, 취침 여부, 수면유도 노래 설정 |
| `rooms` | 방 이름, 소유자 uid/이름, 온라인 노크 활성화 여부 |
| `knocks` | 노크 요청(room_id, requester_uid, owner_uid, status: pending/approved/denied) |
| `todos` | 사용자별 할 일 (text, done, done_at) |
| `schedules` | 날짜별 일정 (uid, date `yyyy/MM/dd`, title) |
| `suggestions` | 익명 건의사항 (작성자 정보 없음) |
| `chats` / `messages` | 1:1 매신저 대화방과 메시지 |
| `draws` | 추첨 이력 (참가자 목록, 당첨자) |
| `sleep_sessions` | 취침~기상 세션 기록 (잔 시간 계산용) |
| `alarms` | 사용자별 알람 (시각, 반복 방식, 알람음) |
| `meta` | "첫 계정 = 관리자" 규칙을 보장하기 위한 잠금 값 |

REST API 엔드포인트 목록은 `server/src/routes/*.js`를 참고하세요. 인증은
`Authorization: Bearer <JWT>` 헤더로, 실시간 이벤트는 같은 토큰으로 맺는 Socket.io 연결로
전달됩니다.

## 용어 정의 매핑

- **관리자 계정**: `role == 'admin'`, 시스템에 1명만 존재(회원가입 시 서버 트랜잭션으로 보장)
- **소유자**: `rooms.owner_uid`가 자신인 사용자. 관리자가 배정/해제
- **요청자**: 온라인 노크를 보낸 사용자
- **on/off**: 각 기능의 boolean 활성화 상태 (예: `accessOpen`, `knockEnabled`, `sleepMusicEnabled`)
- **시간/날**: 전부 KST 기준 (앱: `lib/services/kst_time.dart`, 서버: `server/src/kst.js`),
  날짜 형식은 `년/월/일`

## 프로젝트 구조

```
server/
  src/
    db.js              # SQLite 스키마
    auth.js             # JWT 발급/검증, 비밀번호 해시
    permissions.js       # 관리자 권한 체크
    socket.js            # Socket.io 실시간 이벤트
    kst.js                # 한국 표준시 유틸
    serializers.js         # DB row → API JSON 변환
    routes/                 # 리소스별 REST 엔드포인트
  test/api.test.js          # 백엔드 통합 테스트 (node --test)

lib/
  models/          # 데이터 모델
  services/
    api_client.dart     # 서버 REST 클라이언트 (토큰/서버주소 영구 저장)
    socket_service.dart  # Socket.io 실시간 이벤트 구독
    live_query.dart       # REST + 소켓 이벤트를 Stream으로 합쳐주는 헬퍼
    kst_time.dart           # 한국 표준시 유틸
    alarm_notification_service.dart  # Android 알람 보조 알림
    *_repository.dart                 # 리소스별 데이터 접근
  screens/
    auth/          # 서버 주소 입력, 로그인/회원가입
    home/          # 하단 탭 뼈대(HomeShell), 더보기 화면
    status/        # 상태창
    knock/         # 온라인 노크
    messenger/     # 온라인 매신저(1:1 채팅)
    todo/          # 할 일 목록
    schedule/      # 일정
    suggestion/    # 건의사항
    draw/          # 추첨
    sleep/         # 취침/기상
    alarm/         # 알람 목록/편집/알림창
    admin/         # 관리자 전용
  widgets/         # 공용 위젯 (실시간 시계 등)
  app_session.dart # 서버 연결·로그인 세션 상태 (ChangeNotifier)
  main.dart        # 앱 진입점, 라우팅
assets/sounds/     # 알람음·수면유도 음악 (직접 합성한 wav)
tools/generate_sounds.py  # 위 wav 파일 생성 스크립트
```

## 알려진 제한 사항

- Windows에서는 알람/노크 실시간 알림 모두 **앱이 실행 중일 때만** 동작합니다
  (flutter_local_notifications가 Windows 백그라운드 실행을 지원하지 않음).
- 알람 커스텀 음원은 `file_picker`로 선택한 기기 내 파일 경로를 그대로 재생합니다. 다른 기기로
  옮기거나 파일이 삭제되면 재생할 수 없으니, 필요하면 내장 알람음(3종) 사용을 권장합니다.
- 프로필 사진은 이니셜 아바타만 제공합니다(파일 업로드는 별도 스토리지 연동이 필요해 범위 밖).
- 서버는 단일 SQLite 파일을 사용하므로 소규모 룸메이트 그룹(수십 명 이하) 기준으로 설계되었습니다.
- 서버 인증은 단일 JWT(만료 30일)를 사용하며, 리프레시 토큰/이메일 인증 등 프로덕션급 보안
  강화는 범위 밖입니다. 실사용 전 `JWT_SECRET`을 반드시 무작위 값으로 바꾸고, 가능하면 HTTPS
  리버스 프록시(예: Caddy, nginx) 뒤에 서버를 두는 것을 권장합니다.
