import 'dart:async';

import '../models/alarm.dart';
import 'api_client.dart';
import 'kst_time.dart';
import 'local_notifications_service.dart';

typedef AlarmFireCallback = void Function(Alarm alarm);

/// 앱이 실행 중일 때(포그라운드) 알람 목록을 주기적으로 확인해 정확한 시간에
/// 벨소리 화면을 띄운다. 앱이 백그라운드/종료 상태일 때의 알림은
/// [LocalNotificationsService]가 보조한다.
class AlarmScheduler {
  final LocalNotificationsService localNotifications;
  AlarmScheduler({required this.localNotifications});

  Timer? _timer;
  List<Alarm> _alarms = [];
  final Set<String> _firedKeys = {};
  AlarmFireCallback? onFire;

  Future<void> refresh(ApiClient api) async {
    try {
      final res = await api.get('/alarms');
      _alarms = (res['alarms'] as List<dynamic>)
          .map((e) => Alarm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final alarm in _alarms) {
        await localNotifications.scheduleAlarm(alarm);
      }
    } catch (_) {
      // 네트워크 오류 시 다음 주기에 다시 시도한다.
    }
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    final now = KstTime.now();
    final hm = KstTime.hm(now);
    final today = KstTime.isoDate(now);
    // 백엔드 요일 규약: 0=일 .. 6=토. dart DateTime.weekday: 1=월 .. 7=일.
    final backendWeekday = now.weekday % 7;

    if (_firedKeys.length > 500) _firedKeys.clear();

    for (final alarm in _alarms) {
      if (!alarm.enabled || alarm.time != hm) continue;

      final matches = switch (alarm.repeatType) {
        'daily' => true,
        'weekly' => alarm.repeatDays.contains(backendWeekday),
        'date' => alarm.specificDate == today,
        _ => false,
      };
      if (!matches) continue;

      final key = '${alarm.id}_${today}_$hm';
      if (_firedKeys.contains(key)) continue;
      _firedKeys.add(key);
      onFire?.call(alarm);
    }
  }
}
