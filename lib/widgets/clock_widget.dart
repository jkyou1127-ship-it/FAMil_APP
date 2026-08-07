import 'dart:async';

import 'package:flutter/material.dart';

import '../services/kst_time.dart';

/// 실시간 한국 표준시(KST) 시계.
class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key, this.compact = false});

  final bool compact;

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Timer _timer;
  DateTime _now = KstTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = KstTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Text(
        KstTime.formatTimeShort(_now),
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          KstTime.formatTime(_now),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${KstTime.formatDate(_now)} (한국표준시)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
