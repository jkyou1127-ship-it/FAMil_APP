import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';

/// 관리자 패널: 방을 만들고, 각 방의 소유자(실제로 그 방에서 생활하는 사람)를 배정한다.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<Room> _rooms = [];
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    try {
      final roomsRes = await api.get('/rooms');
      final usersRes = await api.get('/users');
      final rooms = (roomsRes['rooms'] as List<dynamic>)
          .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final users = (usersRes['users'] as List<dynamic>)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _users = users;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createRoom() async {
    final api = context.read<ApiClient>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 방 만들기'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '방 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('만들기')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await api.post('/rooms', {'name': name.trim()});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _renameRoom(Room room) async {
    final api = context.read<ApiClient>();
    final controller = TextEditingController(text: room.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방 이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '방 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('변경')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == room.name) return;
    try {
      await api.patch('/rooms/${room.id}/name', {'name': name.trim()});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _assignOwner(Room room) async {
    final api = context.read<ApiClient>();
    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _users
              .map((u) => ListTile(
                    title: Text(u.displayName),
                    subtitle: Text(u.roomId != null ? '이미 다른 방에 배정됨' : '배정된 방 없음'),
                    onTap: () => Navigator.of(context).pop(u),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected == null) return;
    try {
      await api.post('/rooms/${room.id}/assign-owner', {'userId': selected.id});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _ownerName(int? ownerId) {
    if (ownerId == null) return '미배정';
    final match = _users.where((u) => u.id == ownerId);
    return match.isNotEmpty ? match.first.displayName : '알 수 없음';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 패널')),
      floatingActionButton: FloatingActionButton(onPressed: _createRoom, child: const Icon(Icons.add_home_outlined)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('방 목록', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (_rooms.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('아직 만들어진 방이 없습니다.')),
                  ..._rooms.map((room) => ListTile(
                        leading: const Icon(Icons.meeting_room_outlined),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(room.name)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: '방 이름 변경',
                              onPressed: () => _renameRoom(room),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        subtitle: Text('소유자: ${_ownerName(room.ownerId)} · ${room.accessStatus == 'open' ? '출입 가능' : '출입 불가'}'),
                        trailing: TextButton(
                          onPressed: () => _assignOwner(room),
                          child: const Text('소유자 배정'),
                        ),
                      )),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('전체 사용자', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ..._users.map((u) => ListTile(
                        leading: Icon(u.isAdmin ? Icons.shield : Icons.person_outline),
                        title: Text(u.displayName),
                        subtitle: Text(u.isAdmin ? '관리자' : (u.roomId != null ? '방 배정됨' : '방 미배정')),
                      )),
                ],
              ),
            ),
    );
  }
}
