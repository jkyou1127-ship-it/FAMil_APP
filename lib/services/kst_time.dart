import 'package:intl/intl.dart';

/// 한국 표준시(KST, UTC+9) 관련 유틸리티.
///
/// 기기의 시간대 설정과 무관하게 항상 실제 UTC 시각을 기준으로
/// KST(+9시간)를 계산하므로, 기기 시간대가 다르게 설정돼 있어도
/// 정확한 한국 시간을 표시한다.
class KstTime {
  KstTime._();

  static const Duration _offset = Duration(hours: 9);

  /// 현재 KST 벽시계 시각 (naive DateTime, 표시 전용).
  static DateTime now() => DateTime.now().toUtc().add(_offset);

  /// 임의의 순간(Instant)을 KST 벽시계 시각으로 변환한다.
  static DateTime toKst(DateTime dateTime) =>
      dateTime.toUtc().add(_offset);

  /// '년/월/일' 형식의 날짜 문자열.
  static String formatDate(DateTime dateTime) =>
      DateFormat('yyyy/MM/dd').format(dateTime);

  /// 'HH:mm:ss' 형식의 시각 문자열.
  static String formatTime(DateTime dateTime) =>
      DateFormat('HH:mm:ss').format(dateTime);

  /// 'HH:mm' 형식의 시각 문자열.
  static String formatTimeShort(DateTime dateTime) =>
      DateFormat('HH:mm').format(dateTime);

  static String formatDateTime(DateTime dateTime) =>
      '${formatDate(dateTime)} ${formatTime(dateTime)}';

  /// 두 순간이 KST 기준으로 같은 날짜인지 확인한다.
  static bool isSameKstDay(DateTime a, DateTime b) {
    final ka = toKst(a);
    final kb = toKst(b);
    return ka.year == kb.year && ka.month == kb.month && ka.day == kb.day;
  }
}
