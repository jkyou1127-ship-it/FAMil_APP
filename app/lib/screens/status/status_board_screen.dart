import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/status_entry.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../widgets/kst_clock_widget.dart';
import '../../widgets/user_avatar.dart';

/// 상태창 + 온라인 노크 진입점. 각 사용자의 프로필 사진, 방 출입 가능 여부,
/// 온/오프라인, 취침 여부, 오늘 일정을 한눈에 보여준다.
/// 다른 사람의 방을 탭하면 온라인 노크를 보낸다.
class StatusBoardScreen extends StatefulWidget {
  const StatusBoardScreen({super.key});

  @override
  State<StatusBoardScreen> createState() => _StatusBoardScreenState();
}

class _StatusBoardScreenState extends State<StatusBoardScreen> {
  List<StatusEntry> _board = [];
  bool _loading = true;
  String? _error;
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('status:update', _onUpdate);
    _socket.on('rooms:update', _onUpdate);
    _load();
  }

  @override
  void dispose() {
    _socket.off('status:update', _onUpdate);
    _socket.off('rooms:update', _onUpdate);
    super.dispose();
  }

  void _onUpdate(dynamic _) => _load();

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/status');
      final board = (res['board'] as List<dynamic>)
          .map((e) => StatusEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _board = board;
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _knock(StatusEntry entry) async {
    final api = context.read<ApiClient>();
    try {
      await api.post('/rooms/${entry.room!.id}/knock');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${entry.displayName}님에게 노크했습니다.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleAccess(StatusEntry entry) async {
    final api = context.read<ApiClient>();
    final next = entry.room!.accessStatus == 'open' ? 'closed' : 'open';
    try {
      await api.patch('/rooms/${entry.room!.id}/access', {'status': next});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('상태창'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Center(child: KstClockWidget()),
                      const SizedBox(height: 24),
                      Text('가족 상태', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_board.isEmpty) const Text('등록된 사용자가 없습니다.'),
                      ..._board.map((entry) {
                        final isMe = me != null && entry.userId == me.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: UserAvatar(photoUrl: entry.profilePhoto, name: entry.displayName, online: entry.online),
                            title: Row(
                              children: [
                                Flexible(child: Text(entry.displayName, overflow: TextOverflow.ellipsis)),
                                if (entry.isAdmin) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.shield, size: 14, color: Colors.blueGrey),
                                ],
                                if (entry.sleepStatus == 'sleeping') ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.bedtime, size: 14, color: Colors.indigo),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.room == null
                                    ? '배정된 방 없음'
                                    : '${entry.room!.name} · ${entry.room!.accessStatus == 'open' ? '출입 가능' : '출입 불가'}'),
                                if (entry.todaySchedules.isNotEmpty)
                                  Text('오늘: ${entry.todaySchedules.join(', ')}',
                                      style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            trailing: entry.room == null
                                ? null
                                : isMe
                                    ? Switch(
                                        value: entry.room!.accessStatus == 'open',
                                        onChanged: (_) => _toggleAccess(entry),
                                      )
                                    : (entry.room!.knockEnabled
                                        ? IconButton(
                                            icon: const Icon(Icons.back_hand_outlined),
                                            tooltip: '노크하기',
                                            onPressed: () => _knock(entry),
                                          )
                                        : const Icon(Icons.lock_outline, color: Colors.grey)),
                          ),
                        );
                      }),
                    ],
                  ),
      ),
    );
  }
}
