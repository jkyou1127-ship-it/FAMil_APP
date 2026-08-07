import 'package:flutter/material.dart';

import '../todo/todo_tab.dart';
import 'schedule_tab.dart';

/// 일정 시스템 + 할 일 목록을 하나의 화면에서 탭으로 오간다.
class ScheduleTodoScreen extends StatelessWidget {
  const ScheduleTodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('일정 / 할 일'),
          bottom: const TabBar(tabs: [Tab(text: '일정'), Tab(text: '할 일 목록')]),
        ),
        body: const TabBarView(children: [ScheduleTab(), TodoTab()]),
      ),
    );
  }
}
