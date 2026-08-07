import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 앱 전체에서 "현재시간"은 기기 시간대와 무관하게 항상 한국 표준시(KST)를 의미한다.
class KstTime {
  static late final tz.Location _seoul;
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _seoul = tz.getLocation('Asia/Seoul');
    _initialized = true;
  }

  static tz.TZDateTime now() => tz.TZDateTime.now(_seoul);

  static tz.TZDateTime fromIso(String iso) => tz.TZDateTime.from(DateTime.parse(iso), _seoul);

  /// 년/월/일 형식의 "날" 표기.
  static String krDate([tz.TZDateTime? at]) {
    final t = at ?? now();
    return '${t.year}/${t.month}/${t.day}';
  }

  static String hms([tz.TZDateTime? at]) => DateFormat('HH:mm:ss').format(at ?? now());

  static String hm([tz.TZDateTime? at]) => DateFormat('HH:mm').format(at ?? now());

  static String weekdayKr([tz.TZDateTime? at]) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    final t = at ?? now();
    return names[t.weekday - 1];
  }

  static String isoDate([tz.TZDateTime? at]) => DateFormat('yyyy-MM-dd').format(at ?? now());
}
