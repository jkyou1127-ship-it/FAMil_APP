# FAMil APP

가족/룸메이트 공유 생활 공간을 위한 실시간 관리 앱입니다. 모든 시간은 한국 표준시(KST, `Asia/Seoul`)를 기준으로 동작합니다.

두 부분으로 구성됩니다.

- **`backend/`** — Node.js + Express + Socket.IO + SQLite 자체 백엔드 서버 (로그인, 실시간 알림/메신저, 데이터 저장)
- **`app/`** — Flutter 클라이언트. 하나의 코드베이스로 **Android APK**와 **Windows/Linux 데스크톱 앱**을 모두 빌드합니다.

## 용어

- **관리자 계정**: 시스템 전체를 구성하는 계정. 시스템에 딱 1명만 존재하며, **가장 먼저 가입한 계정이 자동으로 관리자**가 됩니다.
- **소유자**: 어떤 방에 실제로 생활하는 사람. 관리자가 방에 배정합니다.
- **요청자**: 소유자에게 온라인 노크 등을 통해 무언가를 요청하는 사람.
- **상태창**: 프로필 사진, 방의 출입 가능 여부, 온/오프라인, 취침 여부, 오늘 일정을 보여주는 화면.

## 기능 ↔ 코드 매핑

| 기능 | 백엔드 | 클라이언트 |
|---|---|---|
| 로그인 / 관리자(첫 계정) | `backend/src/routes/auth.js` | `app/lib/screens/auth/` |
| 온라인 노크 | `backend/src/routes/rooms.js` (`/rooms/:id/knock`, `/rooms/knocks/*`) + 소켓 | `app/lib/screens/status/status_board_screen.dart`, `home_shell.dart` (전역 알림) |
| 온라인 매신저 | `backend/src/routes/messages.js` + 소켓 `message:*` | `app/lib/screens/messenger/` |
| 건의사항 (익명) | `backend/src/routes/suggestions.js` | `app/lib/screens/suggestions/` |
| 출입 가능/불가능 전환 | `backend/src/routes/rooms.js` (`PATCH /rooms/:id/access`) | `status_board_screen.dart`의 스위치 |
| 상태창 | `backend/src/routes/status.js` | `status_board_screen.dart` |
| 추첨 | `backend/src/routes/lottery.js` | `app/lib/screens/lottery/` |
| 취침/기상 + 수면유도 노래 | `backend/src/routes/sleep.js` | `app/lib/screens/sleep/` |
| 알람 (매일/요일별/날짜지정) | `backend/src/routes/alarms.js` | `app/lib/screens/alarms/` + `services/alarm_scheduler.dart`, `services/local_notifications_service.dart` |
| 일정 | `backend/src/routes/schedules.js` | `app/lib/screens/schedule/schedule_tab.dart` |
| 할 일 목록 (완료 후 하루 지나면 삭제) | `backend/src/routes/todos.js` + `backend/src/cron/index.js` | `app/lib/screens/todo/todo_tab.dart` |
| 시계 (KST) | `backend/src/utils/time.js` | `app/lib/widgets/kst_clock_widget.dart` |
| 관리자: 방 생성 / 소유자 배정 | `backend/src/routes/rooms.js` | `app/lib/screens/admin/admin_panel_screen.dart` |

## 1. 백엔드 실행

```bash
cd backend
cp .env.example .env
# .env의 JWT_SECRET을 임의의 긴 문자열로 변경하세요.
npm install
npm start
```

기본적으로 `http://0.0.0.0:4000` 에서 실행됩니다. 데이터는 SQLite 파일(`backend/data/famil.db`)에 저장됩니다.

end-to-end 스모크 테스트(회원가입/노크/메신저/건의사항/추첨/취침/알람/일정/할일 전체 흐름 검증):

```bash
npm run smoketest
```

### 실기기(휴대폰)에서 접속하려면

같은 Wi-Fi 안에서 PC의 사설 IP(예: `192.168.0.10`)로 백엔드를 실행하고, 앱에서 서버 주소를 `http://192.168.0.10:4000` 으로 설정하세요. (로그인 화면 우측 상단 아이콘 또는 앱 내 "더보기 → 서버 주소 설정")

## 2. Flutter 앱 빌드

### 사전 준비

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable 채널)
- Android APK 빌드: Android Studio + Android SDK/NDK
- Windows 빌드: Windows 10/11 + Visual Studio (Desktop development with C++)
- Linux 빌드: `clang`, `cmake`, `ninja-build`, `libgtk-3-dev` 등 ([공식 가이드](https://docs.flutter.dev/platform-integration/linux/building))

```bash
cd app
flutter pub get
```

### Android APK

```bash
flutter build apk --release
# 결과물: app/build/app/outputs/flutter-apk/app-release.apk
```

> 배포용 서명 키가 없으면 디버그 서명으로 빌드됩니다. 실제 배포 전에는
> `android/key.properties` + 릴리즈 서명 설정을 추가하세요
> (https://docs.flutter.dev/deployment/android).

### Windows 데스크톱

```bash
flutter build windows --release
```

### Linux 데스크톱

```bash
flutter build linux --release
```

### 개발 중 바로 실행해보기

```bash
flutter run            # 연결된 기기/에뮬레이터
flutter run -d windows  # Windows
flutter run -d linux    # Linux
flutter run -d chrome   # 웹 (참고용)
```

앱을 처음 실행하면 로그인 화면에서 서버 주소를 설정할 수 있습니다 (기본값 `http://localhost:4000`). 에뮬레이터에서 PC의 localhost 백엔드에 접속하려면 Android 에뮬레이터는 `http://10.0.2.2:4000`을 사용하세요.

## 실시간 동작 방식

클라이언트는 Socket.IO로 백엔드에 연결되어 다음을 실시간으로 받습니다.

- `knock:new` / `knock:responded` — 온라인 노크 알림/응답
- `message:new` — 매신저 메시지
- `status:update` / `rooms:update` — 상태창(온오프라인, 출입 가능 여부 등) 변경
- `lottery:drawn` — 추첨 결과 전체 브로드캐스트

## 알람 시스템의 동작과 한계

- **앱이 실행 중일 때**: 15초 간격으로 알람 목록을 확인해 정확한 시각에 전체화면 벨소리 화면을 띄우고, 설정한 노래(기본 제공 3곡 중 선택 또는 사용자가 직접 넣은 음원 파일)를 반복 재생합니다. "알람 끄기"를 누르면 소리가 끊기고 화면이 닫힙니다.
- **앱이 백그라운드/종료 상태일 때(Android)**: `flutter_local_notifications`로 OS 알림을 함께 예약해 신뢰도를 보완합니다. 알람 화면 우측 상단의 방패 아이콘(백그라운드 알람 권한 설정)에서 **알림 권한**, **정확한 알람 권한**, **배터리 최적화 제외**를 한 화면에서 확인하고 바로 허용할 수 있습니다. 이 세 가지를 모두 허용하면 앱을 백그라운드로 보내거나 완전히 종료해도 알람이 울릴 가능성이 크게 높아집니다. 다만 제조사별 절전 정책(예: 일부 중국 제조사의 강화된 절전 모드)에 따라 여전히 지연되거나 울리지 않을 수 있습니다 — 이는 스토어에 등록되지 않은 알람 앱의 일반적인 한계입니다.
- **Windows/Linux 데스크톱**: OS 차원의 백그라운드 알람 예약을 지원하지 않으므로, 앱이 실행 중이어야 알람이 울립니다.
- 반복 방식은 매일 / 요일별(복수 선택) / 날짜 지정 3가지를 지원합니다.

## 사운드 에셋

`app/assets/sounds/`에는 저작권 문제 없이 자체 생성한 사인파 톤 시퀀스가 들어 있습니다 (`backend`가 아닌 순수 스크립트로 합성, 외부 샘플 미사용).

- `alarm_tone1.wav`, `alarm_tone2.wav`, `alarm_tone3.wav` — 알람 기본 제공 사운드 3종
- `sleep_lullaby.wav` — 수면 유도 사운드

사용자는 알람 설정 화면에서 기기에 있는 다른 음원 파일을 직접 선택해 사용할 수도 있습니다.

## 보안/운영 참고

- 이 백엔드는 **자체 호스팅**을 전제로 합니다. 외부에 노출할 경우 반드시 HTTPS 리버스 프록시(예: nginx + Let's Encrypt)를 앞단에 두고, `.env`의 `CORS_ORIGIN`을 실제 도메인으로 제한하세요.
- Android 클라이언트는 사설 네트워크에서 평문 HTTP로 접속할 수 있도록 `usesCleartextTraffic="true"`가 설정되어 있습니다. 공인 인터넷에 노출한다면 HTTPS로 전환하고 이 옵션을 제거하는 것을 권장합니다.
- 비밀번호는 bcrypt로 해싱되어 저장되며, 인증은 JWT(기본 30일 만료)를 사용합니다.
