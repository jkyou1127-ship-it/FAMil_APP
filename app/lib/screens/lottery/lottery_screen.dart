import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lottery.dart';
import '../../services/api_client.dart';
import '../../services/socket_service.dart';

/// 추첨 시스템: 현재 온라인인 인원 중에서 추첨한다.
class LotteryScreen extends StatefulWidget {
  const LotteryScreen({super.key});

  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen> {
  List<LotteryResult> _history = [];
  bool _loading = true;
  bool _drawing = false;
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('lottery:drawn', _onDrawn);
    _load();
  }

  @override
  void dispose() {
    _socket.off('lottery:drawn', _onDrawn);
    super.dispose();
  }

  void _onDrawn(dynamic _) => _load();

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/lottery/history');
      final list = (res['history'] as List<dynamic>)
          .map((e) => LotteryResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) setState(() {
        _history = list;
        _loading = false;
      });
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _draw() async {
    setState(() => _drawing = true);
    try {
      await context.read<ApiClient>().post('/lottery/draw');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추첨')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton.icon(
              onPressed: _drawing ? null : _draw,
              icon: const Icon(Icons.casino),
              label: Text(_drawing ? '추첨 중...' : '지금 추첨하기'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(child: Text('추첨 기록이 없습니다.'))
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, i) {
                          final r = _history[i];
                          return ListTile(
                            leading: const Icon(Icons.emoji_events_outlined),
                            title: Text('${r.winnerName}님 당첨'),
                            subtitle: Text('참여 인원 ${r.participantIds.length}명'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
