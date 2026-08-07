import 'dart:async';

import 'package:flutter/material.dart';

import '../services/kst_time.dart';

/// 시계 기능: 한국 표준시로 현재 시각을 1초마다 갱신해 보여준다.
class KstClockWidget extends StatefulWidget {
  final bool compact;
  const KstClockWidget({super.key, this.compact = false});

  @override
  State<KstClockWidget> createState() => _KstClockWidgetState();
}

class _KstClockWidgetState extends State<KstClockWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = KstTime.now();
    final timeText = KstTime.hms(now);
    final dateText = '${KstTime.krDate(now)} (${KstTime.weekdayKr(now)})';

    if (widget.compact) {
      return Text(timeText, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeText,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 4),
        Text('$dateText · 한국표준시(KST)', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
