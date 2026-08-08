import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// backend/src/utils/time.js와 동일한 규약을 따르는 서버용 KST 시간 유틸.
/// (클라이언트 표시용인 services/kst_time.dart와는 별개 — 이쪽은 저장/정렬용
/// ISO 문자열과, 요일 0=일..6=토라는 백엔드 와이어 규약을 그대로 재현한다.)
class ServerTime {
  static late final tz.Location _seoul;
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _seoul = tz.getLocation('Asia/Seoul');
    _initialized = true;
  }

  /// 저장/정렬에 안전한 UTC 순간의 ISO-8601 문자열.
  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  static tz.TZDateTime _toKst(String? iso) => iso != null
      ? tz.TZDateTime.from(DateTime.parse(iso), _seoul)
      : tz.TZDateTime.now(_seoul);

  /// KST 달력 날짜 (YYYY-MM-DD).
  static String kstDateString([String? iso]) {
    final t = _toKst(iso);
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 요일 인덱스, 0=일 .. 6=토 (dayjs().day()와 동일한 규약, Flutter
  /// 클라이언트의 `now.weekday % 7` 계산과도 일치한다).
  static int kstWeekday([String? iso]) => _toKst(iso).weekday % 7;
}
