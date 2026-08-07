import 'package:famil_app/services/kst_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KstTime.formatDate 는 년/월/일 형식이다', () {
    final dateTime = DateTime.utc(2026, 8, 7, 3, 0, 0); // UTC 03:00 -> KST 12:00
    final kst = KstTime.toKst(dateTime);
    expect(KstTime.formatDate(kst), '2026/08/07');
  });

  test('KstTime.isSameKstDay 는 자정 전후를 구분한다', () {
    final beforeMidnightUtc = DateTime.utc(2026, 8, 6, 14, 59); // KST 23:59
    final afterMidnightUtc = DateTime.utc(2026, 8, 6, 15, 1); // KST 00:01 (다음날)
    expect(KstTime.isSameKstDay(beforeMidnightUtc, afterMidnightUtc), isFalse);
  });
}
