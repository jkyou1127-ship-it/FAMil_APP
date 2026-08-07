import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android에서 알람이 백그라운드/종료 상태에서도 최대한 신뢰성 있게 울리도록
/// 필요한 권한(알림, 정확한 알람, 배터리 최적화 제외)의 상태를 확인하고
/// 시스템 설정 화면으로 안내한다. Android 외 플랫폼에서는 아무 것도 하지 않는다.
class AlarmPermissionsService {
  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<PermissionStatus> notificationStatus() =>
      isSupported ? Permission.notification.status : Future.value(PermissionStatus.granted);

  Future<PermissionStatus> exactAlarmStatus() =>
      isSupported ? Permission.scheduleExactAlarm.status : Future.value(PermissionStatus.granted);

  Future<PermissionStatus> batteryOptimizationStatus() => isSupported
      ? Permission.ignoreBatteryOptimizations.status
      : Future.value(PermissionStatus.granted);

  Future<PermissionStatus> requestNotification() => Permission.notification.request();

  Future<PermissionStatus> requestExactAlarm() => Permission.scheduleExactAlarm.request();

  Future<PermissionStatus> requestBatteryOptimizationExemption() =>
      Permission.ignoreBatteryOptimizations.request();

  Future<void> openSystemSettings() => openAppSettings();
}
