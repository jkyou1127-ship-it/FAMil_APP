import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/sleep_session.dart';
import '../../services/kst_time.dart';
import '../../services/sleep_repository.dart';
import '../../services/sound_library.dart';
import '../../services/user_repository.dart';

/// 취침과 기상 시스템: 취침 시간 기록 + 수면유도 노래 재생, 기상 시 잔 시간 표시.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final _userRepo = UserRepository();
  final _sleepRepo = SleepRepository();
  final _player = AudioPlayer();

  Timer? _musicStopTimer;
  bool _musicPlaying = false;
  int _musicMinutes = 15;

  @override
  void dispose() {
    _musicStopTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _stopMusic() async {
    _musicStopTimer?.cancel();
    if (_musicPlaying) {
      await _player.stop();
      if (mounted) setState(() => _musicPlaying = false);
    }
  }

  Future<void> _startMusic(int minutes) async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource(
        SoundLibrary.sleepMusic.assetPath.replaceFirst('assets/', '')));
    setState(() => _musicPlaying = true);
    _musicStopTimer?.cancel();
    _musicStopTimer = Timer(Duration(minutes: minutes), _stopMusic);
  }

  Future<void> _goToSleep(bool musicEnabled) async {
    final me = widget.session.currentUser!;
    final now = DateTime.now();
    await _userRepo.setSleeping(me.uid, sleeping: true, sleepStartedAt: now);
    if (musicEnabled) {
      await _startMusic(_musicMinutes);
    }
  }

  Future<void> _wakeUp() async {
    final me = widget.session.currentUser!;
    final sleptAt = me.sleepStartedAt;
    final wokeAt = DateTime.now();
    await _stopMusic();
    await _userRepo.setSleeping(me.uid, sleeping: false, sleepStartedAt: null);
    if (sleptAt != null) {
      await _sleepRepo.saveSession(uid: me.uid, sleptAt: sleptAt, wokeAt: wokeAt);
      if (mounted) {
        final duration = wokeAt.difference(sleptAt);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('좋은 아침입니다'),
            content: Text('잔 시간: ${_formatDuration(duration)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h시간 $m분';
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.session.currentUser!;
    final uid = me.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  me.isSleeping ? Icons.bedtime : Icons.wb_sunny_outlined,
                  size: 56,
                  color: me.isSleeping ? Colors.indigo : Colors.orange,
                ),
                const SizedBox(height: 8),
                Text(
                  me.isSleeping ? '취침 중' : '기상 상태',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (me.isSleeping && me.sleepStartedAt != null)
                  Text(
                    '취침 시각: ${KstTime.formatDateTime(KstTime.toKst(me.sleepStartedAt!))}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 16),
                if (!me.isSleeping) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('수면유도 노래'),
                    subtitle: const Text('끄면 다시 켤 때까지 계속 꺼진 상태로 유지됩니다'),
                    value: me.sleepMusicEnabled,
                    onChanged: (value) =>
                        _userRepo.setSleepMusicEnabled(uid, value),
                  ),
                  if (me.sleepMusicEnabled)
                    Row(
                      children: [
                        const Text('재생 시간(분): '),
                        Expanded(
                          child: Slider(
                            value: _musicMinutes.toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label: '$_musicMinutes분',
                            onChanged: (v) =>
                                setState(() => _musicMinutes = v.round()),
                          ),
                        ),
                        Text('$_musicMinutes'),
                      ],
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _goToSleep(me.sleepMusicEnabled),
                    icon: const Icon(Icons.bedtime),
                    label: const Text('취침하기'),
                  ),
                ] else ...[
                  if (_musicPlaying)
                    TextButton.icon(
                      onPressed: _stopMusic,
                      icon: const Icon(Icons.music_off),
                      label: const Text('수면유도 노래 끄기'),
                    ),
                  FilledButton.icon(
                    onPressed: _wakeUp,
                    icon: const Icon(Icons.wb_sunny),
                    label: const Text('기상하기'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('최근 수면 기록', style: Theme.of(context).textTheme.titleMedium),
        StreamBuilder<List<SleepSession>>(
          stream: _sleepRepo.watchMySessions(uid),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];
            if (sessions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('기록이 없습니다.', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: sessions.map((s) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.nightlight_round),
                    title: Text(_formatDuration(s.duration)),
                    subtitle: Text(
                      '${KstTime.formatDateTime(KstTime.toKst(s.sleptAt))} '
                      '~ ${KstTime.formatDateTime(KstTime.toKst(s.wokeAt))}',
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
