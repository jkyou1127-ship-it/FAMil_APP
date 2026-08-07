import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../config/alarm_sounds.dart';
import '../../models/alarm.dart';
import '../../services/kst_time.dart';

/// 알람이 울릴 시각이 되면 전체 화면으로 표시되는 벨소리 화면.
/// 설정한 노래를 반복 재생하고, "알람 끄기"를 누르면 소리가 끊기며 화면이 닫힌다.
class AlarmRingScreen extends StatefulWidget {
  final Alarm alarm;
  const AlarmRingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);
    final asset = widget.alarm.sound.startsWith('custom:')
        ? widget.alarm.sound.substring('custom:'.length)
        : alarmAssetFor(widget.alarm.sound);
    if (widget.alarm.sound.startsWith('custom:')) {
      _player.play(DeviceFileSource(asset));
    } else {
      _player.play(AssetSource(asset.replaceFirst('assets/', '')));
    }
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    await _player.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm, size: 96, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(height: 16),
                Text(
                  KstTime.hm(),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (widget.alarm.label?.isNotEmpty ?? false) ? widget.alarm.label! : '알람',
                  style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                ),
                const SizedBox(height: 48),
                FilledButton.tonal(
                  onPressed: _stop,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  ),
                  child: const Text('알람 끄기', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
