import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/alarm.dart';
import '../../models/knock.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/push_service.dart';
import '../../services/socket_service.dart';
import '../alarms/alarm_list_screen.dart';
import '../alarms/alarm_ring_screen.dart';
import '../messenger/chat_list_screen.dart';
import '../more/more_screen.dart';
import '../schedule/schedule_todo_screen.dart';
import '../status/status_board_screen.dart';

/// 로그인 이후 앱의 뼈대. 하단 탭 전환과 함께, 어느 화면에 있든 실시간으로
/// 도착하는 온라인 노크 알림을 처리한다.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _unreadMessages = 0;

  late final SocketService _socket;
  late final AlarmScheduler _alarmScheduler;

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('knock:new', _onKnockNew);
    _socket.on('knock:responded', _onKnockResponded);
    _socket.on('message:new', _onMessageNew);

    _alarmScheduler = context.read<AlarmScheduler>();
    _alarmScheduler.onFire = _onAlarmFire;
    _alarmScheduler.refresh(context.read<ApiClient>());
    _alarmScheduler.start();

    context.read<PushService>().init(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _socket.off('knock:new', _onKnockNew);
    _socket.off('knock:responded', _onKnockResponded);
    _socket.off('message:new', _onMessageNew);
    _alarmScheduler.stop();
    _alarmScheduler.onFire = null;
    super.dispose();
  }

  void _onAlarmFire(Alarm alarm) {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => AlarmRingScreen(alarm: alarm), fullscreenDialog: true),
    );
  }

  void _onKnockNew(dynamic data) {
    if (!mounted) return;
    final knock = Knock.fromJson(Map<String, dynamic>.from(data as Map));
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('온라인 노크'),
        content: Text('${knock.requesterName}님이 "${knock.roomName}" 방에 노크했습니다.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _respond(knock.id, false);
            },
            child: const Text('거절'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _respond(knock.id, true);
            },
            child: const Text('승인'),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(int knockId, bool approve) async {
    try {
      await context.read<ApiClient>().post('/rooms/knocks/$knockId/respond', {'approve': approve});
    } on ApiException catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onKnockResponded(dynamic data) {
    final knock = Knock.fromJson(Map<String, dynamic>.from(data as Map));
    final text = knock.status == 'approved'
        ? '"${knock.roomName}" 방 노크가 승인되었습니다.'
        : '"${knock.roomName}" 방 노크가 거절되었습니다.';
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }

  void _onMessageNew(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;
    if (map['receiverId'] == me.id && _index != 1) {
      setState(() => _unreadMessages += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const StatusBoardScreen(),
      const ChatListScreen(),
      const ScheduleTodoScreen(),
      const AlarmListScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            if (i == 1) _unreadMessages = 0;
          });
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text('$_unreadMessages'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: '매신저',
          ),
          const NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: '일정/할일'),
          const NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm), label: '알람'),
          const NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: '더보기'),
        ],
      ),
    );
  }
}
