import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/alarm.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/api_client.dart';
import 'alarm_edit_screen.dart';
import 'alarm_permissions_screen.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

String describeRepeat(Alarm alarm) {
  switch (alarm.repeatType) {
    case 'daily':
      return '매일';
    case 'weekly':
      final days = [...alarm.repeatDays]..sort();
      return days.map((d) => _weekdayLabels[d]).join(', ');
    case 'date':
      return alarm.specificDate ?? '날짜 미지정';
    default:
      return alarm.repeatType;
  }
}

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  List<Alarm> _alarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/alarms');
      final list = (res['alarms'] as List<dynamic>)
          .map((e) => Alarm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _alarms = list;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) context.read<AlarmScheduler>().refresh(context.read<ApiClient>());
  }

  Future<void> _toggle(Alarm alarm, bool enabled) async {
    try {
      await context.read<ApiClient>().patch('/alarms/${alarm.id}', {'enabled': enabled});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Alarm alarm) async {
    try {
      await context.read<ApiClient>().delete('/alarms/${alarm.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알람'),
        actions: [
          IconButton(
            icon: const Icon(Icons.security_outlined),
            tooltip: '백그라운드 알람 권한 설정',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlarmPermissionsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlarmEditScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _alarms.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Text('등록된 알람이 없습니다.'))])
                  : ListView.builder(
                      itemCount: _alarms.length,
                      itemBuilder: (context, i) {
                        final alarm = _alarms[i];
                        return Dismissible(
                          key: ValueKey(alarm.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _delete(alarm),
                          child: ListTile(
                            title: Text(alarm.time, style: const TextStyle(fontSize: 24)),
                            subtitle: Text(
                              [
                                describeRepeat(alarm),
                                if (alarm.label != null && alarm.label!.isNotEmpty) alarm.label!,
                              ].join(' · '),
                            ),
                            trailing: Switch(
                              value: alarm.enabled,
                              onChanged: (v) => _toggle(alarm, v),
                            ),
                            onTap: () async {
                              await Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: alarm)));
                              _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
