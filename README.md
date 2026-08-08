# FAMil APP

가족/룸메이트 공유 생활 공간을 위한 실시간 관리 앱입니다. 모든 시간은 한국 표준시(KST, `Asia/Seoul`)를 기준으로 동작합니다.

두 부분으로 구성됩니다.

- **`backend/`** — Node.js + Express + WebSocket + SQLite 자체 백엔드 서버 (로그인, 실시간 알림/메신저, 데이터 저장)
- **`app/`** — Flutter 클라이언트. 하나의 코드베이스로 **Android APK**와 **Windows 데스크톱 앱**을 모두 빌드합니다.

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
| 취침/기상 + 수면유도 노래 | `backend/src/routes/sleep.js` | `app/lib/screens/sleep/` |
| 알람 (매일/요일별/날짜지정) | `backend/src/routes/alarms.js` | `app/lib/screens/alarms/` + `services/alarm_scheduler.dart`, `services/local_notifications_service.dart` |
| 일정 | `backend/src/routes/schedules.js` | `app/lib/screens/schedule/schedule_tab.dart` |
| 할 일 목록 (완료 후 하루 지나면 삭제) | `backend/src/routes/todos.js` + `backend/src/cron/index.js` | `app/lib/screens/todo/todo_tab.dart` |
| 단톡방 (그룹 채팅) | `backend/src/routes/chatRooms.js` + 소켓 `group:*` | `app/lib/screens/messenger/group_chat_list_view.dart`, `group_chat_screen.dart` |
| 장보기 목록 (온 가족 공유) | `backend/src/routes/shopping.js` + 소켓 `shopping:update` | `app/lib/screens/shopping/shopping_list_screen.dart` |
| 백업 서버 (PC가 꺼졌을 때 다른 기기를 임시 서버로) | `backend/src/routes/backup.js` + `app/lib/server/`(내장 Dart 서버) | `app/lib/screens/admin/backup_server_screen.dart` |
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

end-to-end 스모크 테스트(회원가입/노크/메신저/건의사항/취침/알람/일정/할일 전체 흐름 검증):

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

> GitHub Actions로 빌드한 `famil-app-windows` 아티팩트는 앱뿐 아니라 백엔드와 Node.js 런타임까지
> 함께 묶여 있습니다. 압축을 풀고 **`FAMil_시작.bat`** 을 더블클릭하면 백엔드 서버가 자동으로
> 백그라운드에서 켜지고 이어서 앱이 실행됩니다 — 별도로 `npm start`를 실행할 필요가 없습니다.
> 첫 실행 시 Windows SmartScreen이 "알 수 없는 게시자" 경고를 띄울 수 있는데, 서명되지 않은
> 개인 빌드라서 나오는 정상적인 경고입니다. **"추가 정보" → "실행"** 을 누르면 진행됩니다.

### 개발 중 바로 실행해보기

```bash
flutter run            # 연결된 기기/에뮬레이터
flutter run -d windows  # Windows
flutter run -d chrome   # 웹 (참고용)
```

앱을 처음 실행하면 로그인 화면에서 서버 주소를 설정할 수 있습니다 (기본값 `http://localhost:4000`). 에뮬레이터에서 PC의 localhost 백엔드에 접속하려면 Android 에뮬레이터는 `http://10.0.2.2:4000`을 사용하세요.

## 실시간 동작 방식

클라이언트는 WebSocket(`/realtime?token=...`)으로 백엔드에 연결되어 다음을 실시간으로 받습니다.

- `knock:new` / `knock:responded` — 온라인 노크 알림/응답
- `message:new` — 매신저 메시지
- `group:room:new` / `group:message:new` — 단톡방 초대/메시지
- `shopping:update` — 장보기 목록 변경(추가/체크/삭제)
- `status:update` / `rooms:update` — 상태창(온오프라인, 출입 가능 여부 등) 변경

## 알람 시스템의 동작과 한계

- **앱이 실행 중일 때**: 15초 간격으로 알람 목록을 확인해 정확한 시각에 전체화면 벨소리 화면을 띄우고, 설정한 노래(기본 제공 3곡 중 선택 또는 사용자가 직접 넣은 음원 파일)를 반복 재생합니다. "알람 끄기"를 누르면 소리가 끊기고 화면이 닫힙니다.
- **앱이 백그라운드/종료 상태일 때(Android)**: `flutter_local_notifications`로 OS 알림을 함께 예약해 신뢰도를 보완합니다. 알람 화면 우측 상단의 방패 아이콘(백그라운드 알람 권한 설정)에서 **알림 권한**, **정확한 알람 권한**, **배터리 최적화 제외**를 한 화면에서 확인하고 바로 허용할 수 있습니다. 이 세 가지를 모두 허용하면 앱을 백그라운드로 보내거나 완전히 종료해도 알람이 울릴 가능성이 크게 높아집니다. 다만 제조사별 절전 정책(예: 일부 중국 제조사의 강화된 절전 모드)에 따라 여전히 지연되거나 울리지 않을 수 있습니다 — 이는 스토어에 등록되지 않은 알람 앱의 일반적인 한계입니다.
- **Windows 데스크톱**: OS 차원의 백그라운드 알람 예약을 지원하지 않으므로, 앱이 실행 중이어야 알람이 울립니다.
- 반복 방식은 매일 / 요일별(복수 선택) / 날짜 지정 3가지를 지원합니다.

## 사운드 에셋

`app/assets/sounds/`에는 다음 음원이 들어 있습니다.

- `alarm_tone4.mp3`, `alarm_tone5.mp3`, `alarm_tone6.mp3` — 알람 기본 제공 사운드 3종
- `sleep_lullaby.mp3`, `sleep_lullaby2.mp3` — 수면 유도 사운드 (취침 화면에서 곡 선택 가능, 매끄럽게 반복 재생됨)

사용자는 알람 설정 화면에서 기기에 있는 다른 음원 파일을 직접 선택해 사용할 수도 있습니다.

## 백업 서버 (임시)

PC 백엔드가 꺼져 있을 때, 로그인한 가족 구성원 누구나 **더보기 → 백업 서버 (임시)** 화면에서 자기 기기(폰 또는 다른 Windows PC)를 같은 Wi-Fi 안에서만 쓰는 임시 서버로 켤 수 있습니다. Flutter 앱에 내장된 Dart 서버(`app/lib/server/`)를 그대로 사용하며, 별도 설치가 필요 없습니다.

- **평소**: PC 백엔드가 켜져 있을 때 "지금 스냅샷 저장"으로 계정/데이터의 스냅샷을 미리 받아둡니다.
- **PC가 꺼졌을 때**: "백업 서버로 시작"을 누르면 이 기기가 서버가 되고, 기존과 동일한 UDP 자동 감지 프로토콜에 응답하기 시작합니다 — 다른 가족은 로그인 화면의 "같은 Wi-Fi에서 자동 감지"로 이 기기를 찾아 기존 계정 그대로 다시 로그인하면 됩니다.
- **PC가 복구되면**: "주 서버로 복귀"를 누르면 백업 중 쌓인 메시지/단톡방 메시지/할 일/일정/건의사항/장보기 항목을 PC로 병합한 뒤 자동으로 중지됩니다. 백업 중 새로 만든 계정이나 방/단톡방은 병합 대상에서 제외됩니다.
- 자동으로 전환되지 않습니다 — 여러 기기가 동시에 서버가 되는 상황(split-brain)을 피하기 위해 항상 사용자가 버튼을 직접 눌러야 동작합니다.
- Android에서는 앱이 백그라운드로 가도 서버가 유지되도록 포그라운드 서비스로 실행됩니다. Windows는 앱이 실행 중이기만 하면 됩니다.

## 집 밖에서도 사용하기 (외부 접속)

기본 설정(같은 Wi-Fi에서 사설 IP로 접속)은 집 안에서만 동작합니다. 밖에서도 쓰려면 아래 방법 중 하나로 백엔드를 외부에 노출해야 합니다.

### 방법 A. Cloudflare Tunnel (추천 — 무료, 공유기 설정 불필요)

집 PC에서 백엔드를 그대로 실행하면서, 포트포워딩이나 고정 IP 없이 안전하게 외부에 노출하는 가장 쉬운 방법입니다. Cloudflare 계정(무료)만 있으면 됩니다.

```bash
# 1) cloudflared 설치 (예: macOS)
brew install cloudflared
# Windows는 https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ 참고

# 2) 백엔드를 평소대로 켠 상태에서, 터널로 4000번 포트를 외부에 연결
cloudflared tunnel --url http://localhost:4000
```

실행하면 `https://xxxx-xxxx.trycloudflare.com` 같은 임시 공개 주소가 나옵니다. 이 주소를 앱의 "서버 주소 설정"에 입력하면 밖에서도 접속됩니다. (매번 실행할 때마다 주소가 바뀌는 임시 터널입니다. 고정 주소가 필요하면 Cloudflare 계정에 도메인을 연결해 "명명된 터널(named tunnel)"을 만드세요 — [공식 가이드](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/).)

### 방법 B. Docker로 클라우드에 배포

`backend/Dockerfile`이 포함되어 있어 Render, Fly.io, Railway 등 어떤 컨테이너 호스팅에도 올릴 수 있습니다. 예시로 [Fly.io](https://fly.io) 기준 (`backend/fly.toml` 포함, 앱 이름/리전은 원하는 값으로 수정):

```bash
cd backend
brew install flyctl   # 또는 https://fly.io/docs/flyctl/install/
fly auth login
fly launch --no-deploy          # fly.toml을 그대로 사용할지 물으면 예
fly volumes create famil_data --size 1   # SQLite 데이터를 보관할 영구 볼륨
fly secrets set JWT_SECRET="$(openssl rand -hex 32)"
fly deploy
```

배포가 끝나면 `https://<앱이름>.fly.dev` 주소가 생기고, 이를 앱의 서버 주소로 입력하면 됩니다. 이 방식은 PC를 항상 켜둘 필요가 없다는 장점이 있는 대신, SQLite 데이터가 서버 쪽에 저장되므로 볼륨을 반드시 연결해야 데이터가 유지됩니다.

### 방법 C. 공유기 포트포워딩 + DDNS (고급)

전통적인 방법이지만 집 IP가 그대로 노출되고 보안 설정을 직접 관리해야 하므로, 방법 A(Cloudflare Tunnel)를 먼저 권장합니다. 굳이 이 방법을 쓴다면 공유기에서 4000번 포트를 백엔드 PC로 포워딩하고, DDNS(예: 공유기 제조사 제공 DDNS, No-IP 등)로 도메인을 연결한 뒤, 반드시 nginx/Caddy 같은 리버스 프록시로 HTTPS를 앞단에 두세요.

## 보안/운영 참고

- 이 백엔드는 **자체 호스팅**을 전제로 합니다. 외부에 노출할 경우 반드시 HTTPS(위 방법 A의 Cloudflare Tunnel은 자동으로 HTTPS를 제공합니다)를 사용하고, `.env`의 `CORS_ORIGIN`을 실제 도메인으로 제한하세요.
- Android 클라이언트는 사설 네트워크에서 평문 HTTP로 접속할 수 있도록 `usesCleartextTraffic="true"`가 설정되어 있습니다. 공인 인터넷에 노출한다면 HTTPS로 전환하고 이 옵션을 제거하는 것을 권장합니다.
- 비밀번호는 bcrypt로 해싱되어 저장되며, 인증은 JWT(기본 30일 만료)를 사용합니다.
