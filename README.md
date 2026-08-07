# 패밀 (FAMil) — 룸메이트 관리 앱

온라인 노크, 매신저, 상태창, 추첨, 취침/기상, 알람, 일정, 할 일 목록 등을 제공하는
룸메이트 관리 앱입니다. Flutter 하나의 코드베이스로 **Android APK**와 **Windows 데스크톱(PC)**
앱을 모두 빌드하며, Firebase(Auth + Cloud Firestore)로 로그인과 실시간 데이터를 처리합니다.
모든 시각 정보는 기기 시간대와 무관하게 **한국 표준시(KST, UTC+9)** 기준으로 계산·표시됩니다.

## 구현된 기능

- **로그인/회원가입** (이메일·비밀번호), **첫 번째 가입 계정 = 관리자 자동 지정**
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

## 기술 스택

- **Flutter 3.44 (stable)** — Android / Windows / Web 공용 코드베이스
- **Firebase Auth / Cloud Firestore** — 로그인 및 실시간 데이터
- **provider** — 로그인 세션 상태 관리
- **audioplayers** — 알람음 · 수면유도 노래 재생
- **flutter_local_notifications + timezone** — (Android 전용) 알람 백그라운드 보조 알림
- **file_picker** — 알람음 직접 선택

> Windows 데스크톱은 FlutterFire의 공식 Windows 플러그인(C++ 래퍼, Firebase C++ SDK 기반)을
> 사용합니다. **Linux 데스크톱은 FlutterFire가 공식 지원하지 않아 이 프로젝트에서 제외했습니다.**
> (macOS/iOS는 요청 범위에 없어 스캐폴딩하지 않았습니다. 필요하면 `flutter create --platforms=ios,macos .`
> 로 추가할 수 있습니다.)

## 알람 시스템 동작 방식 (중요)

알람은 두 겹으로 동작합니다.

1. **앱 내부 알람 엔진** (`lib/screens/home/home_shell.dart`): 앱이 실행 중일 때 1초마다 현재
   KST 시각과 등록된 알람을 비교합니다. 일치하면 알람음을 반복 재생하고 전체화면 알람창을 띄우며,
   "알람 끄기"를 눌러야 소리가 멈추고 창이 닫힙니다. Android/Windows 모두에서 동일하게 동작합니다.
2. **Android 전용 백그라운드 보조 알림** (`lib/services/alarm_notification_service.dart`):
   `flutter_local_notifications`로 정확한 시각에 시스템 알림을 예약합니다. 앱이 백그라운드에
   있거나 완전히 종료된 상태에서도 사용자에게 알려주기 위한 보조 수단입니다. 단, 이 알림은
   내장/커스텀 알람음이 아닌 기본 알림음을 사용합니다(안드로이드 raw 리소스로 커스텀 음원을
   등록하는 작업은 범위 밖으로 남겨두었습니다). **Windows는 FlutterFire와 마찬가지로
   flutter_local_notifications도 공식 지원하지 않으므로, Windows에서는 앱이 실행 중일 때만
   알람이 울립니다.**
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

### 1. Firebase 프로젝트 준비

1. [Firebase 콘솔](https://console.firebase.google.com/)에서 새 프로젝트를 만듭니다.
2. **Authentication → Sign-in method**에서 "이메일/비밀번호"를 활성화합니다.
3. **Firestore Database**를 생성합니다(프로덕션 모드 권장).
4. 이 저장소에 포함된 `firestore.rules`, `firestore.indexes.json`을 배포합니다.
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase use --add   # 방금 만든 프로젝트 선택
   firebase deploy --only firestore:rules,firestore:indexes
   ```

### 2. 앱에 Firebase 연결

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

플랫폼 선택 시 **android, windows, web**을 선택하세요. 명령이 끝나면
`lib/firebase_options.dart`가 실제 프로젝트 값으로 자동 교체됩니다.
(현재 저장소의 `firebase_options.dart`는 자리표시자이며, 이 값 그대로 실행하면
"Firebase 설정이 필요합니다" 안내 화면이 표시됩니다.)

### 3. 실행

```bash
flutter pub get
flutter run              # 연결된 기기/에뮬레이터에서 실행
flutter run -d windows   # Windows 데스크톱
```

### 4. 빌드

```bash
flutter build apk --release       # Android APK (build/app/outputs/flutter-apk/)
flutter build windows --release   # Windows 실행 파일 (build/windows/x64/runner/Release/)
```

Android SDK/Windows 빌드 도구가 없는 환경(예: 이 저장소를 만든 CI 컨테이너)에서는 로컬 빌드가
불가능하므로, `.github/workflows/build.yml`에 GitHub Actions 워크플로를 포함했습니다. 저장소를
GitHub에 push하면 자동으로 (1) `flutter analyze`/`flutter test`, (2) Android APK, (3) Windows
실행 파일을 빌드하고 Actions 실행 결과의 Artifacts에서 내려받을 수 있습니다.

## 데이터 모델 (Firestore)

| 컬렉션 | 설명 |
|---|---|
| `users/{uid}` | 이메일, 이름, 권한(admin/member), 배정된 roomId, 온라인 여부, 출입 가능 여부, 취침 여부, 수면유도 노래 설정 |
| `rooms/{roomId}` | 방 이름, 소유자 uid/이름, 온라인 노크 활성화 여부 |
| `knocks/{id}` | 노크 요청(roomId, requesterUid, ownerUid, status: pending/approved/denied) |
| `todos/{id}` | 사용자별 할 일 (text, done, doneAt) |
| `schedules/{id}` | 날짜별 일정 (uid, date `yyyy/MM/dd`, title) |
| `suggestions/{id}` | 익명 건의사항 (작성자 정보 없음) |
| `chats/{chatId}` → `messages/{id}` | 1:1 매신저 대화방과 메시지 |
| `draws/{id}` | 추첨 이력 (참가자 목록, 당첨자) |
| `sleepSessions/{id}` | 취침~기상 세션 기록 (잔 시간 계산용) |
| `alarms/{id}` | 사용자별 알람 (시각, 반복 방식, 알람음) |
| `meta/adminAssigned` | "첫 계정 = 관리자" 규칙을 보장하기 위한 잠금 문서 |

## 용어 정의 매핑

- **관리자 계정**: `role == 'admin'`, 시스템에 1명만 존재(회원가입 트랜잭션으로 보장)
- **소유자**: `rooms.ownerUid`가 자신인 사용자. 관리자가 배정/해제
- **요청자**: 온라인 노크를 보낸 사용자
- **on/off**: 각 기능의 boolean 활성화 상태 (예: `accessOpen`, `knockEnabled`, `sleepMusicEnabled`)
- **시간/날**: 전부 KST 기준 (`lib/services/kst_time.dart`), 날짜 형식은 `년/월/일`

## 프로젝트 구조

```
lib/
  models/          # 데이터 모델
  services/        # Firebase 연동 리포지토리 + KST 시간 유틸 + 알람 엔진 보조 서비스
  screens/
    auth/          # 로그인/회원가입
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
  app_session.dart # 로그인 세션 상태 (ChangeNotifier)
  main.dart        # 앱 진입점, Firebase 초기화, 라우팅
assets/sounds/     # 알람음·수면유도 음악 (직접 합성한 wav)
tools/generate_sounds.py  # 위 wav 파일 생성 스크립트
```

## 알려진 제한 사항

- Windows에서는 알람/노크 실시간 알림 모두 **앱이 실행 중일 때만** 동작합니다(공식 FlutterFire·
  flutter_local_notifications가 Windows 백그라운드 실행을 지원하지 않음).
- 알람 커스텀 음원은 `file_picker`로 선택한 기기 내 파일 경로를 그대로 재생합니다. 다른 기기로
  옮기거나 파일이 삭제되면 재생할 수 없으니, 필요하면 내장 알람음(3종) 사용을 권장합니다.
- 프로필 사진은 이니셜 아바타만 제공합니다(파일 업로드는 Firebase Storage 연동이 필요해 범위 밖).
