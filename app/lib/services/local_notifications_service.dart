import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm.dart';
import 'kst_time.dart';

/// 앱이 백그라운드/종료 상태일 때도 최대한 알람을 울리기 위한 보조 계층.
/// (포그라운드에서는 [AlarmScheduler]가 실제 사용자 지정 사운드로 벨소리 화면을 띄운다.
/// 여기서는 OS 알림을 예약해, 기기의 절전 모드/제조사 정책에 따라 신뢰도가 달라질 수 있다.)
class LocalNotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    try {
      await _plugin.initialize(settings: initSettings);
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {
      // 데스크톱 등 알림 플러그인을 지원하지 않는 플랫폼에서는 조용히 건너뛴다.
      _ready = false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'famil_alarms',
          '알람',
          channelDescription: 'FAMil APP 알람 알림',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      );

  tz.TZDateTime _nextDaily(int hour, int minute) {
    final now = KstTime.now();
    var when = tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    return when;
  }

  tz.TZDateTime _nextForWeekday(int backendWeekday, int hour, int minute) {
    // backendWeekday: 0=Sun..6=Sat. dart TZDateTime.weekday: 1=Mon..7=Sun.
    final dartWeekday = backendWeekday == 0 ? 7 : backendWeekday;
    var when = _nextDaily(hour, minute);
    while (when.weekday != dartWeekday) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }

  tz.TZDateTime? _forDate(String isoDate, int hour, int minute) {
    final parts = isoDate.split('-').map(int.parse).toList();
    final now = KstTime.now();
    final when = tz.TZDateTime(now.location, parts[0], parts[1], parts[2], hour, minute);
    return when.isAfter(now) ? when : null;
  }

  Future<void> scheduleAlarm(Alarm alarm) async {
    await cancelAlarm(alarm.id);
    if (!_ready || !alarm.enabled) return;

    final parts = alarm.time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final title = (alarm.label != null && alarm.label!.isNotEmpty) ? alarm.label! : '알람';

    try {
      if (alarm.repeatType == 'daily') {
        await _plugin.zonedSchedule(
          id: alarm.id,
          scheduledDate: _nextDaily(hour, minute),
          title: title,
          body: '설정한 시간이 되었습니다.',
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'alarm:${alarm.id}',
        );
      } else if (alarm.repeatType == 'weekly') {
        for (final day in alarm.repeatDays) {
          await _plugin.zonedSchedule(
            id: alarm.id * 10 + day,
            scheduledDate: _nextForWeekday(day, hour, minute),
            title: title,
            body: '설정한 시간이 되었습니다.',
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'alarm:${alarm.id}',
          );
        }
      } else if (alarm.repeatType == 'date' && alarm.specificDate != null) {
        final when = _forDate(alarm.specificDate!, hour, minute);
        if (when != null) {
          await _plugin.zonedSchedule(
            id: alarm.id,
            scheduledDate: when,
            title: title,
            body: '설정한 시간이 되었습니다.',
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'alarm:${alarm.id}',
          );
        }
      }
    } catch (_) {
      // 정확 알람 권한이 없는 등 예약이 실패해도 포그라운드 스케줄러는 계속 동작한다.
    }
  }

  Future<void> cancelAlarm(int alarmId) async {
    if (!_ready) return;
    await _plugin.cancel(id: alarmId);
    for (var day = 0; day < 7; day++) {
      await _plugin.cancel(id: alarmId * 10 + day);
    }
  }
}
