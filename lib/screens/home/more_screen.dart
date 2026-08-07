import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../admin/admin_screen.dart';
import '../alarm/alarm_list_screen.dart';
import '../draw/draw_screen.dart';
import '../schedule/schedule_screen.dart';
import '../sleep/sleep_screen.dart';
import '../suggestion/suggestion_screen.dart';

class _MoreEntry {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  const _MoreEntry(this.label, this.icon, this.builder);
}

/// 자주 쓰지 않는 기능들을 모아두는 화면 (하단 탭이 너무 많아지는 것을 방지).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final me = session.currentUser!;
    final entries = <_MoreEntry>[
      _MoreEntry('일정', Icons.calendar_month_outlined,
          (_) => ScheduleScreen(session: session)),
      _MoreEntry('건의함', Icons.mail_outline, (_) => const SuggestionScreen()),
      _MoreEntry('추첨', Icons.casino_outlined, (_) => DrawScreen(session: session)),
      _MoreEntry('취침/기상', Icons.bedtime_outlined,
          (_) => SleepScreen(session: session)),
      _MoreEntry('알람', Icons.alarm, (_) => AlarmListScreen(session: session)),
      if (me.isAdmin)
        _MoreEntry('관리자', Icons.admin_panel_settings_outlined,
            (_) => const AdminScreen()),
    ];

    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: entries.map((e) {
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(e.label)),
                body: Builder(builder: e.builder),
              ),
            )),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(e.icon, size: 32),
                const SizedBox(height: 8),
                Text(e.label),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
