import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/app_user.dart';
import '../../models/draw_event.dart';
import '../../services/draw_repository.dart';
import '../../services/kst_time.dart';
import '../../services/user_repository.dart';

/// 추첨 시스템: 현재 인원 중에서 무작위로 한 명을 뽑는다.
class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  final _userRepo = UserRepository();
  final _drawRepo = DrawRepository();
  final _titleController = TextEditingController();

  final Set<String> _excluded = {};
  bool _spinning = false;
  String? _spinDisplayName;
  AppUser? _winner;
  Timer? _spinTimer;

  @override
  void dispose() {
    _spinTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _runDraw(List<AppUser> candidates) async {
    if (candidates.isEmpty || _spinning) return;
    setState(() {
      _spinning = true;
      _winner = null;
    });

    final random = Random();
    var ticks = 0;
    final maxTicks = 18 + random.nextInt(6);
    _spinTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      ticks++;
      setState(() {
        _spinDisplayName = candidates[random.nextInt(candidates.length)].displayName;
      });
      if (ticks >= maxTicks) {
        timer.cancel();
        final winner = candidates[random.nextInt(candidates.length)];
        setState(() {
          _winner = winner;
          _spinDisplayName = winner.displayName;
          _spinning = false;
        });
        _drawRepo.saveDraw(DrawEvent(
          id: '',
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          participantUids: candidates.map((u) => u.uid).toList(),
          participantNames: candidates.map((u) => u.displayName).toList(),
          winnerUid: winner.uid,
          winnerName: winner.displayName,
          createdByUid: widget.session.currentUser!.uid,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _userRepo.watchAllUsers(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final candidates =
            all.where((u) => !_excluded.contains(u.uid)).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '추첨 제목 (선택)',
                hintText: '예: 청소 당번 뽑기',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('참가자 (${candidates.length}명)',
                style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: all
                  .map((u) => FilterChip(
                        label: Text(u.displayName),
                        selected: !_excluded.contains(u.uid),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _excluded.remove(u.uid);
                          } else {
                            _excluded.add(u.uid);
                          }
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events,
                        size: 48,
                        color: _winner != null ? Colors.amber : Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      _spinDisplayName ?? '참가자를 선택하고 추첨을 시작하세요',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: candidates.isEmpty || _spinning
                          ? null
                          : () => _runDraw(candidates),
                      icon: const Icon(Icons.casino),
                      label: Text(_spinning ? '추첨 중...' : '추첨하기'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('추첨 이력', style: Theme.of(context).textTheme.titleMedium),
            StreamBuilder<List<DrawEvent>>(
              stream: _drawRepo.watchHistory(),
              builder: (context, historySnap) {
                final history = historySnap.data ?? [];
                if (history.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('추첨 이력이 없습니다.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return Column(
                  children: history.map((e) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text('${e.title ?? '추첨'} → ${e.winnerName}'),
                        subtitle: Text(
                          '참가자 ${e.participantUids.length}명'
                          '${e.createdAt != null ? ' · ${KstTime.formatDateTime(KstTime.toKst(e.createdAt!))}' : ''}',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
