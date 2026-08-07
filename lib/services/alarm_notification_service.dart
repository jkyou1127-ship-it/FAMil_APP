import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm.dart';

/// 알람의 백그라운드(앱이 꺼져있거나 화면 밖일 때) 보조 알림.
///
/// FlutterFire의 in-app 알람 엔진(HomeShell)이 앱 실행 중에는 커스텀 알람음과
/// "알람 끄기" 화면으로 정확하게 동작하지만, 앱이 완전히 종료된 상태에서는
/// 앱 내부 타이머가 동작하지 않는다. 이를 보완하기 위해 Android에서만
/// 시스템 알림을 예약한다. (FlutterFire 플러그인이 Windows를 지원하지 않아
/// Windows에서는 앱이 실행 중일 때만 알람이 울린다.)
class AlarmNotificationService {
  AlarmNotificationService._();
  static final AlarmNotificationService instance = AlarmNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (!_supported || _initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
    _initialized = true;
  }

  int _baseId(String alarmId) => alarmId.hashCode & 0x7fffffff;

  Future<void> cancelForAlarm(String alarmId) async {
    if (!_supported) return;
    final base = _baseId(alarmId);
    // weekly 알람은 요일별로 최대 7개의 알림 id(base+1..base+7)를 사용한다.
    for (var i = 0; i <= 7; i++) {
      await _plugin.cancel(base + i);
    }
  }

  Future<void> scheduleForAlarm(Alarm alarm) async {
    if (!_supported) return;
    await cancelForAlarm(alarm.id);
    if (!alarm.enabled) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'famil_alarm_channel',
        '패밀 알람',
        channelDescription: '설정한 시각에 울리는 알람 보조 알림',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      ),
    );

    final base = _baseId(alarm.id);

    switch (alarm.repeat) {
      case AlarmRepeat.daily:
        await _plugin.zonedSchedule(
          base,
          alarm.label,
          '설정한 알람 시간입니다 (${alarm.timeLabel})',
          _nextInstanceOfTime(alarm.hour, alarm.minute),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        break;
      case AlarmRepeat.weekly:
        for (final weekday in alarm.weekdays) {
          await _plugin.zonedSchedule(
            base + weekday,
            alarm.label,
            '설정한 알람 시간입니다 (${alarm.timeLabel})',
            _nextInstanceOfWeekday(alarm.hour, alarm.minute, weekday),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
        break;
      case AlarmRepeat.once:
        if (alarm.onceDate == null) return;
        final parts = alarm.onceDate!.split('/');
        if (parts.length != 3) return;
        final date = tz.TZDateTime(
          tz.local,
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          alarm.hour,
          alarm.minute,
        );
        if (date.isBefore(tz.TZDateTime.now(tz.local))) return;
        await _plugin.zonedSchedule(
          base,
          alarm.label,
          '설정한 알람 시간입니다 (${alarm.timeLabel})',
          date,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        break;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int hour, int minute, int weekday) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
