import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/alarm.dart';
import '../../models/knock.dart';
import '../../services/alarm_notification_service.dart';
import '../../services/alarm_repository.dart';
import '../../services/knock_repository.dart';
import '../../services/kst_time.dart';
import '../../services/sound_library.dart';
import '../../widgets/clock_widget.dart';
import '../alarm/alarm_ring_screen.dart';
import '../knock/knock_screen.dart';
import '../messenger/chat_list_screen.dart';
import '../status/status_board_screen.dart';
import '../todo/todo_screen.dart';
import 'more_screen.dart';

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

  final _alarmRepo = AlarmRepository();
  final _alarmPlayer = AudioPlayer();
  StreamSubscription<List<Alarm>>? _alarmSub;
  Timer? _alarmTicker;
  List<Alarm> _alarms = [];
  final Set<String> _firedAlarmKeys = {};
  bool _ringing = false;

  @override
  void initState() {
    super.initState();
    final uid = widget.session.currentUser!.uid;
    AlarmNotificationService.instance.init();
    _alarmSub = _alarmRepo.watchMyAlarms(uid).listen((alarms) {
      _alarms = alarms;
      for (final alarm in alarms) {
        AlarmNotificationService.instance.scheduleForAlarm(alarm);
      }
    });
    _alarmTicker = Timer.periodic(const Duration(seconds: 1), (_) => _checkAlarms());
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    _alarmTicker?.cancel();
    _alarmPlayer.dispose();
    super.dispose();
  }

  void _checkAlarms() {
    if (_ringing) return;
    final now = KstTime.now();
    for (final alarm in _alarms) {
      if (!alarm.enabled) continue;
      if (alarm.hour != now.hour || alarm.minute != now.minute) continue;

      final matches = switch (alarm.repeat) {
        AlarmRepeat.daily => true,
        AlarmRepeat.weekly => alarm.weekdays.contains(now.weekday),
        AlarmRepeat.once => alarm.onceDate == KstTime.formatDate(now),
      };
      if (!matches) continue;

      final key = '${alarm.id}_${KstTime.formatDate(now)}_${now.hour}:${now.minute}';
      if (_firedAlarmKeys.add(key)) {
        _ringAlarm(alarm);
        if (alarm.repeat == AlarmRepeat.once) {
          _alarmRepo.setEnabled(alarm.id, false);
        }
      }
    }
  }

  Future<void> _ringAlarm(Alarm alarm) async {
    setState(() => _ringing = true);
    await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
    if (alarm.customSoundPath != null) {
      await _alarmPlayer.play(DeviceFileSource(alarm.customSoundPath!));
    } else {
      final sound = SoundLibrary.alarmSoundById(alarm.soundId);
      await _alarmPlayer
          .play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AlarmRingScreen(
        alarm: alarm,
        onStop: () => _alarmPlayer.stop(),
      ),
    ));
    if (mounted) setState(() => _ringing = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.session.currentUser!;

    final pages = [
      StatusBoardScreen(session: widget.session),
      KnockScreen(session: widget.session),
      ChatListScreen(session: widget.session),
      TodoScreen(session: widget.session),
      MoreScreen(session: widget.session),
    ];

    const destinations = [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '상태창'),
      NavigationDestination(icon: Icon(Icons.front_hand_outlined), label: '노크'),
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '매신저'),
      NavigationDestination(icon: Icon(Icons.checklist_outlined), label: '할일'),
      NavigationDestination(icon: Icon(Icons.more_horiz), label: '더보기'),
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
