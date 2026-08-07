import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/schedule.dart';
import '../../services/api_client.dart';
import '../../services/kst_time.dart';

/// 일정 시스템: 날을 정하고 그 날에 무엇을 해야 하는지 알려준다.
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<String, List<ScheduleItem>> _byDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = KstTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final month = DateFormat('yyyy-MM').format(_focusedDay);
    try {
      final res = await context.read<ApiClient>().get('/schedules', query: {'month': month});
      final list = (res['schedules'] as List<dynamic>)
          .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final grouped = <String, List<ScheduleItem>>{};
      for (final s in list) {
        grouped.putIfAbsent(s.date, () => []).add(s);
      }
      if (mounted) {
        setState(() {
          _byDate = grouped;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<ScheduleItem> _eventsFor(DateTime day) => _byDate[_dateKey(day)] ?? [];

  Future<void> _addSchedule() async {
    final api = context.read<ApiClient>();
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_dateKey(_selectedDay)} 일정 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '할 일을 입력하세요'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('추가')),
        ],
      ),
    );
    if (content == null || content.trim().isEmpty) return;
    try {
      await api.post('/schedules', {'date': _dateKey(_selectedDay), 'content': content.trim()});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteSchedule(ScheduleItem item) async {
    try {
      await context.read<ApiClient>().delete('/schedules/${item.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _eventsFor(_selectedDay);
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _addSchedule, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar<ScheduleItem>(
                  locale: 'ko_KR',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  eventLoader: _eventsFor,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    _focusedDay = focused;
                    _load();
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: selectedEvents.isEmpty
                      ? const Center(child: Text('이 날짜에 등록된 일정이 없습니다.'))
                      : ListView.builder(
                          itemCount: selectedEvents.length,
                          itemBuilder: (context, i) {
                            final item = selectedEvents[i];
                            return ListTile(
                              leading: const Icon(Icons.event),
                              title: Text(item.content),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteSchedule(item),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
