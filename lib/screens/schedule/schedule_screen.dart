import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/schedule_item.dart';
import '../../services/kst_time.dart';
import '../../services/schedule_repository.dart';

/// 일정 시스템: 날을 정하고 그 날에 해야 할 일을 등록/표시한다.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _repo = ScheduleRepository();

  Future<void> _openAddDialog() async {
    final me = widget.session.currentUser!;
    DateTime picked = KstTime.now();
    final titleController = TextEditingController();
    final memoController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('일정 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('날짜: ${KstTime.formatDate(picked)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: picked,
                    firstDate: DateTime(picked.year - 1),
                    lastDate: DateTime(picked.year + 2),
                  );
                  if (selected != null) {
                    setDialogState(() => picked = selected);
                  }
                },
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '할 일'),
              ),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      await _repo.addSchedule(
        uid: me.uid,
        ownerName: me.displayName,
        date: KstTime.formatDate(picked),
        title: titleController.text.trim(),
        memo: memoController.text.trim().isEmpty
            ? null
            : memoController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.session.currentUser!.uid;
    return Scaffold(
      body: StreamBuilder<List<ScheduleItem>>(
        stream: _repo.watchMySchedules(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
                child: Text('등록된 일정이 없습니다.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(item.title),
                  subtitle: Text(
                      item.date + (item.memo != null ? ' · ${item.memo}' : '')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _repo.deleteSchedule(item.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
