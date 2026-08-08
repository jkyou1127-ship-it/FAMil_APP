import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/sleep_sounds.dart';
import '../../models/sleep_record.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';

/// 취침/기상 시스템: 취침 클릭 시 시간이 기록되고, 설정한 시간 동안 수면 유도
/// 노래를 재생할 수 있다(끄면 다시 켤 때까지 계속 꺼진 상태 유지).
/// 기상 클릭 시 기상시간과 잔 시간이 기록된다.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final _player = AudioPlayer();
  List<SleepRecord> _records = [];
  bool _loading = true;
  SleepRecord? _open;
  int _timerMinutes = 30;
  Timer? _stopTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _open != null) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _tickTimer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/sleep/records');
      final list = (res['records'] as List<dynamic>)
          .map((e) => SleepRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final open = list.where((r) => r.wakeAt == null).toList();
      if (mounted) {
        setState(() {
          _records = list;
          _open = open.isNotEmpty ? open.first : null;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sleep() async {
    final api = context.read<ApiClient>();
    final me = context.read<AuthProvider>().currentUser;
    try {
      final res = await api.post('/sleep/start');
      final record = SleepRecord.fromJson(Map<String, dynamic>.from(res['record'] as Map));
      if (mounted) setState(() => _open = record);
      if (me?.sleepSoundEnabled ?? true) {
        final asset = sleepSoundAssetFor(me?.sleepSoundId ?? 'lullaby1');
        await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
        _stopTimer?.cancel();
        _stopTimer = Timer(Duration(minutes: _timerMinutes), () => _player.stop());
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _wake() async {
    try {
      final res = await context.read<ApiClient>().post('/sleep/wake');
      final record = SleepRecord.fromJson(Map<String, dynamic>.from(res['record'] as Map));
      _stopTimer?.cancel();
      await _player.stop();
      if (mounted) {
        setState(() {
          _open = null;
        });
        final h = (record.durationMinutes ?? 0) ~/ 60;
        final m = (record.durationMinutes ?? 0) % 60;
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('기상 완료'),
            content: Text('잔 시간: $h시간 $m분'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
          ),
        );
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleSound(bool enabled) async {
    try {
      await context.read<ApiClient>().patch('/sleep/sound', {'enabled': enabled});
      if (!enabled) {
        _stopTimer?.cancel();
        await _player.stop();
      }
      if (mounted) await context.read<AuthProvider>().refreshMe();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _selectSound(String soundId) async {
    try {
      await context.read<ApiClient>().patch('/sleep/sound', {'enabled': true, 'soundId': soundId});
      if (mounted) await context.read<AuthProvider>().refreshMe();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _elapsed() {
    if (_open == null) return '';
    final start = DateTime.parse(_open!.sleepAt);
    final diff = DateTime.now().toUtc().difference(start.toUtc());
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '$h시간 $m분째 취침 중';
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final soundEnabled = me?.sleepSoundEnabled ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('취침 / 기상')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(_open == null ? Icons.wb_sunny_outlined : Icons.bedtime, size: 48),
                        const SizedBox(height: 8),
                        Text(_open == null ? '깨어있는 중' : _elapsed(), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _open != null ? null : _sleep,
                                icon: const Icon(Icons.bedtime_outlined),
                                label: const Text('취침'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _open == null ? null : _wake,
                                icon: const Icon(Icons.wb_sunny_outlined),
                                label: const Text('기상'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('수면 유도 노래'),
                          subtitle: const Text('끄면 다시 켤 때까지 계속 꺼진 상태로 유지됩니다.'),
                          value: soundEnabled,
                          onChanged: _toggleSound,
                        ),
                        if (soundEnabled) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: me?.sleepSoundId ?? kSleepSounds.first.id,
                            decoration: const InputDecoration(labelText: '곡 선택', border: OutlineInputBorder()),
                            items: kSleepSounds
                                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.label)))
                                .toList(),
                            onChanged: (id) {
                              if (id != null) _selectSound(id);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text('재생 시간: $_timerMinutes분'),
                          Slider(
                            value: _timerMinutes.toDouble(),
                            min: 5,
                            max: 90,
                            divisions: 17,
                            label: '$_timerMinutes분',
                            onChanged: (v) => setState(() => _timerMinutes = v.round()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('최근 기록', style: Theme.of(context).textTheme.titleMedium),
                ..._records.take(10).map((r) => ListTile(
                      leading: const Icon(Icons.history),
                      title: Text('취침 ${DateTime.parse(r.sleepAt).toLocal()}'),
                      subtitle: Text(r.durationMinutes != null
                          ? '잔 시간 ${r.durationMinutes! ~/ 60}시간 ${r.durationMinutes! % 60}분'
                          : '취침 중'),
                    )),
              ],
            ),
    );
  }
}
