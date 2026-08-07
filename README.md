# 패밀 (FAMil) — 룸메이트 관리 앱

온라인 노크, 상태창, 할일 목록, 일정, 건의사항 등을 제공하는 룸메이트 관리 앱입니다.
Flutter 하나의 코드베이스로 **Android APK**와 **Windows 데스크톱(PC)** 앱을 모두 빌드하며,
Firebase(Auth + Cloud Firestore)로 로그인과 실시간 데이터를 처리합니다.
모든 시각 정보는 기기 시간대와 무관하게 **한국 표준시(KST, UTC+9)** 기준으로 계산·표시됩니다.

## 현재 구현 범위 (1차 MVP)

- 로그인 / 회원가입 (이메일·비밀번호), **첫 번째 가입 계정 = 관리자 자동 지정**
- 관리자 화면: 방 생성/삭제, 방에 소유자 배정·해제
- 실시간 KST 시계
- 상태창: 프로필(이니셜 아바타), 출입 가능/불가 표시, 온라인/오프라인, 취침 여부, 오늘 일정 아이콘
- 온라인 노크: 방을 클릭 → 소유자에게 실시간 알림 → 소유자 승인/거절 → 요청자에게 알림
- 온라인 출입 가능/불가능 변경: 소유자가 상태창에서 토글하면 해당 방의 노크 기능이 즉시 비활성화됨
- 할 일 목록: 등록/완료(취소선+회색 처리)/삭제, 완료된 지 하루(한국 날짜 기준)가 지나면 자동 삭제
- 일정 시스템: 날짜별 일정 등록, 상태창에 오늘 일정 표시
- 건의사항: 익명 등록(작성자 정보 저장 안 함), 전체 공개 목록

### 다음 단계로 남겨둔 기능 (스캐폴딩은 되어 있으나 화면 미구현)

- 온라인 매신저(1:1 채팅)
- 추첨 시스템
- 취침/기상 시스템(수면유도 노래 재생, 잔 시간 계산) — 상태창에는 취침 on/off 토글만 우선 반영됨
- 알람 시스템(매일/요일별/날짜 지정 반복, 커스텀 알람음)

이 항목들은 데이터 모델·리포지토리 계층까지는 고려해 설계했으나, 요청 범위(핵심 MVP 우선)에 따라
화면 구현은 다음 작업으로 넘겼습니다. 이어서 진행하려면 채팅 대화에서 요청해 주세요.

## 기술 스택

- **Flutter 3.44 (stable)** — Android / Windows / Web 공용 코드베이스
- **Firebase Auth** — 로그인/회원가입
- **Cloud Firestore** — 실시간 데이터 (사용자, 방, 노크, 할일, 일정, 건의사항)
- **provider** — 상태 관리 (로그인 세션)

> Windows 데스크톱은 FlutterFire의 공식 Windows 플러그인(C++ 래퍼, Firebase C++ SDK 기반)을
> 사용합니다. **Linux 데스크톱은 FlutterFire가 공식 지원하지 않아 이 프로젝트에서 제외했습니다.**
> (macOS/iOS는 요청 범위에 없어 스캐폴딩하지 않았습니다. 필요하면 `flutter create --platforms=ios,macos .`
> 로 추가할 수 있습니다.)

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

Android SDK/Windows 빌드 도구가 없는 환경(예: 이 CI 컨테이너)에서는 로컬 빌드가 불가능하므로,
`.github/workflows/build.yml`에 GitHub Actions 워크플로를 포함했습니다. 저장소를 GitHub에 push하면
자동으로 (1) `flutter analyze`/`flutter test`, (2) Android APK, (3) Windows 실행 파일을 빌드하고
Actions 실행 결과의 Artifacts에서 내려받을 수 있습니다.

## 데이터 모델 (Firestore)

| 컬렉션 | 설명 |
|---|---|
| `users/{uid}` | 이메일, 이름, 권한(admin/member), 배정된 roomId, 온라인 여부, 출입 가능 여부, 취침 여부 |
| `rooms/{roomId}` | 방 이름, 소유자 uid/이름, 온라인 노크 활성화 여부 |
| `knocks/{id}` | 노크 요청(roomId, requesterUid, ownerUid, status: pending/approved/denied) |
| `todos/{id}` | 사용자별 할 일 (text, done, doneAt) |
| `schedules/{id}` | 날짜별 일정 (uid, date `yyyy/MM/dd`, title) |
| `suggestions/{id}` | 익명 건의사항 (작성자 정보 없음) |
| `meta/adminAssigned` | "첫 계정 = 관리자" 규칙을 보장하기 위한 잠금 문서 |

## 용어 정의 매핑

- **관리자 계정**: `role == 'admin'`, 시스템에 1명만 존재(회원가입 트랜잭션으로 보장)
- **소유자**: `rooms.ownerUid`가 자신인 사용자. 관리자가 배정/해제
- **요청자**: 온라인 노크를 보낸 사용자
- **on/off**: 각 기능의 boolean 활성화 상태 (예: `accessOpen`, `knockEnabled`)
- **시간/날**: 전부 KST 기준 (`lib/services/kst_time.dart`), 날짜 형식은 `년/월/일`

## 프로젝트 구조

```
lib/
  models/          # 데이터 모델 (AppUser, Room, Knock, TodoItem, ScheduleItem, Suggestion)
  services/        # Firebase 연동 리포지토리 + KST 시간 유틸
  screens/         # 로그인/회원가입, 상태창, 노크, 할일, 일정, 건의사항, 관리자
  widgets/         # 공용 위젯 (실시간 시계 등)
  app_session.dart # 로그인 세션 상태 (ChangeNotifier)
  main.dart        # 앱 진입점, Firebase 초기화, 라우팅
```
