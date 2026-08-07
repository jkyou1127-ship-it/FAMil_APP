import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/knock.dart';
import '../../services/knock_repository.dart';
import '../../widgets/clock_widget.dart';
import '../admin/admin_screen.dart';
import '../knock/knock_screen.dart';
import '../schedule/schedule_screen.dart';
import '../status/status_board_screen.dart';
import '../suggestion/suggestion_screen.dart';
import '../todo/todo_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final AppSession session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _knockRepo = KnockRepository();
  final Set<String> _shownKnockIds = {};

  @override
  Widget build(BuildContext context) {
    final me = widget.session.currentUser!;
    final isAdmin = me.isAdmin;

    final pages = [
      StatusBoardScreen(session: widget.session),
      KnockScreen(session: widget.session),
      TodoScreen(session: widget.session),
      ScheduleScreen(session: widget.session),
      const SuggestionScreen(),
      if (isAdmin) const AdminScreen(),
    ];

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '상태창'),
      const NavigationDestination(icon: Icon(Icons.front_hand_outlined), label: '노크'),
      const NavigationDestination(icon: Icon(Icons.checklist_outlined), label: '할일'),
      const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '일정'),
      const NavigationDestination(icon: Icon(Icons.mail_outline), label: '건의함'),
      if (isAdmin)
        const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: '관리'),
    ];

    return StreamBuilder<List<Knock>>(
      stream: _knockRepo.watchMyResponses(me.uid),
      builder: (context, snapshot) {
        final responses = snapshot.data ?? [];
        for (final k in responses) {
          if (_shownKnockIds.add(k.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final approved = k.status == KnockStatus.approved;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(approved ? '노크가 승인되었습니다' : '노크가 거절되었습니다'),
                  content: Text('${k.roomName}에 대한 요청이 '
                      '${approved ? '승인' : '거절'}되었습니다.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _knockRepo.acknowledge(k.id);
                        Navigator.pop(context);
                      },
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
            });
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('패밀 · ${me.displayName}'),
            actions: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: ClockWidget(compact: true)),
              ),
              IconButton(
                tooltip: '로그아웃',
                icon: const Icon(Icons.logout),
                onPressed: () => widget.session.signOut(),
              ),
            ],
          ),
          body: pages[_index.clamp(0, pages.length - 1)],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index.clamp(0, destinations.length - 1),
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: destinations,
          ),
        );
      },
    );
  }
}
