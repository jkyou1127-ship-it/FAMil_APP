import 'package:flutter/material.dart';

import '../../models/alarm.dart';

/// 알람이 울릴 때 표시되는 전체화면. "알람 끄기"를 누르면 소리가 끊기고 창이 닫힌다.
class AlarmRingScreen extends StatelessWidget {
  const AlarmRingScreen({
    super.key,
    required this.alarm,
    required this.onStop,
  });

  final Alarm alarm;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alarm, size: 96),
                const SizedBox(height: 16),
                Text(alarm.timeLabel,
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(alarm.label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 48),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                  ),
                  onPressed: () {
                    onStop();
                    Navigator.of(context).pop();
                  },
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
