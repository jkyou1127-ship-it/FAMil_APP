import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/alarm_permissions_service.dart';

/// 알람이 앱을 백그라운드로 보내거나 완전히 종료한 상태에서도 최대한
/// 신뢰성 있게 울리도록, Android에서 필요한 권한을 확인하고 시스템 설정
/// 화면으로 안내하는 화면.
class AlarmPermissionsScreen extends StatefulWidget {
  const AlarmPermissionsScreen({super.key});

  @override
  State<AlarmPermissionsScreen> createState() => _AlarmPermissionsScreenState();
}

class _AlarmPermissionsScreenState extends State<AlarmPermissionsScreen> with WidgetsBindingObserver {
  final _service = AlarmPermissionsService();
  PermissionStatus? _notification;
  PermissionStatus? _exactAlarm;
  PermissionStatus? _batteryOptimization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 시스템 설정 화면에 다녀오면(예: 배터리 최적화 제외 허용) 상태를 다시 읽는다.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notification = await _service.notificationStatus();
    final exactAlarm = await _service.exactAlarmStatus();
    final battery = await _service.batteryOptimizationStatus();
    if (mounted) {
      setState(() {
        _notification = notification;
        _exactAlarm = exactAlarm;
        _batteryOptimization = battery;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('알람 권한 설정')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('이 기기(데스크톱)에서는 별도의 권한 설정이 필요하지 않습니다.\n앱이 실행 중일 때 알람이 울립니다.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('알람 권한 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '앱을 백그라운드로 보내거나 완전히 종료한 상태에서도 알람이 최대한 정확히 울리려면 '
            '아래 권한을 모두 허용해주세요. 기기 제조사의 절전 정책에 따라 일부는 그래도 지연될 수 있습니다.',
          ),
          const SizedBox(height: 16),
          _PermissionTile(
            icon: Icons.notifications_active_outlined,
            title: '알림 권한',
            description: '알람이 울릴 때 알림을 표시하기 위해 필요합니다.',
            status: _notification,
            onRequest: () async {
              await _service.requestNotification();
              _refresh();
            },
          ),
          _PermissionTile(
            icon: Icons.alarm_on_outlined,
            title: '정확한 알람 권한',
            description: '설정한 시각에 정확히 알람을 울리기 위해 필요합니다 (Android 12 이상).',
            status: _exactAlarm,
            onRequest: () async {
              await _service.requestExactAlarm();
              _refresh();
            },
          ),
          _PermissionTile(
            icon: Icons.battery_saver_outlined,
            title: '배터리 최적화 제외',
            description: '앱이 백그라운드/종료 상태여도 절전 모드에 의해 알람이 지연·차단되지 않도록 합니다.',
            status: _batteryOptimization,
            onRequest: () async {
              await _service.requestBatteryOptimizationExemption();
              _refresh();
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _service.openSystemSettings(),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('앱 시스템 설정 직접 열기'),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final PermissionStatus? status;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status?.isGranted ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        isThreeLine: true,
        trailing: status == null
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : granted
                ? const Icon(Icons.check_circle, color: Colors.green)
                : FilledButton(onPressed: onRequest, child: const Text('허용')),
      ),
    );
  }
}
