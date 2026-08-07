import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/alarm.dart';
import '../../services/alarm_repository.dart';
import 'alarm_edit_screen.dart';

const _repeatLabels = {
  AlarmRepeat.daily: '매일',
  AlarmRepeat.weekly: '요일별',
  AlarmRepeat.once: '날짜 지정',
};
const _weekdayShort = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};

class AlarmListScreen extends StatelessWidget {
  AlarmListScreen({super.key, required this.session});

  final AppSession session;
  final _repo = AlarmRepository();

  String _subtitle(Alarm alarm) {
    switch (alarm.repeat) {
      case AlarmRepeat.daily:
        return '매일';
      case AlarmRepeat.weekly:
        final days = alarm.weekdays.toList()..sort();
        return days.map((d) => _weekdayShort[d]).join(', ');
      case AlarmRepeat.once:
        return alarm.onceDate ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = session.currentUser!.uid;
    return Scaffold(
      body: StreamBuilder<List<Alarm>>(
        stream: _repo.watchMyAlarms(uid),
        builder: (context, snapshot) {
          final alarms = snapshot.data ?? [];
          if (alarms.isEmpty) {
            return const Center(
                child: Text('등록된 알람이 없습니다.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return Dismissible(
                key: ValueKey(alarm.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _repo.deleteAlarm(alarm.id),
                child: ListTile(
                  title: Text(
                    alarm.timeLabel,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            color: alarm.enabled
                                ? null
                                : Theme.of(context).disabledColor),
                  ),
                  subtitle: Text(
                      '${alarm.label} · ${_repeatLabels[alarm.repeat]} '
                      '${_subtitle(alarm)}'),
                  trailing: Switch(
                    value: alarm.enabled,
                    onChanged: (v) => _repo.setEnabled(alarm.id, v),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        AlarmEditScreen(uid: uid, existing: alarm),
                  )),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AlarmEditScreen(uid: uid),
        )),
        child: const Icon(Icons.add_alarm),
      ),
    );
  }
}
