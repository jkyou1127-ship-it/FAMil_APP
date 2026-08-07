import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/room.dart';
import '../../services/room_repository.dart';
import '../../services/user_repository.dart';

/// 관리자 전용 화면: 방 생성, 소유자 배정/해제.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _roomRepo = RoomRepository();
  final _userRepo = UserRepository();
  final _newRoomController = TextEditingController();

  @override
  void dispose() {
    _newRoomController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _newRoomController.text.trim();
    if (name.isEmpty) return;
    await _roomRepo.createRoom(name);
    _newRoomController.clear();
  }

  Future<void> _assignOwner(Room room) async {
    final users = await _userRepo.fetchAllUsersOnce();
    if (!mounted) return;
    final selected = await showDialog<AppUser>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${room.name} 소유자 배정'),
        children: users
            .map((u) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, u),
                  child: Text('${u.displayName} (${u.email})'),
                ))
            .toList(),
      ),
    );
    if (selected != null) {
      await _roomRepo.assignOwner(
        roomId: room.id,
        roomName: room.name,
        uid: selected.uid,
        displayName: selected.displayName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('방 관리', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newRoomController,
                decoration: const InputDecoration(
                  hintText: '새 방 이름 (예: 201호)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _createRoom, child: const Text('방 추가')),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Room>>(
          stream: _roomRepo.watchRooms(),
          builder: (context, snapshot) {
            final rooms = snapshot.data ?? [];
            if (rooms.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('등록된 방이 없습니다.', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: rooms.map((room) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.meeting_room),
                    title: Text(room.name),
                    subtitle: Text(room.ownerUid == null
                        ? '소유자 미배정'
                        : '소유자: ${room.ownerName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (room.ownerUid != null)
                          IconButton(
                            tooltip: '소유자 해제',
                            icon: const Icon(Icons.person_remove),
                            onPressed: () => _roomRepo.unassignOwner(
                              roomId: room.id,
                              uid: room.ownerUid!,
                            ),
                          ),
                        IconButton(
                          tooltip: '소유자 배정',
                          icon: const Icon(Icons.person_add),
                          onPressed: () => _assignOwner(room),
                        ),
                        IconButton(
                          tooltip: '방 삭제',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _roomRepo.deleteRoom(room.id),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('전체 사용자', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<List<AppUser>>(
          stream: _userRepo.watchAllUsers(),
          builder: (context, snapshot) {
            final users = snapshot.data ?? [];
            return Column(
              children: users
                  .map((u) => ListTile(
                        leading: CircleAvatar(
                            child: Text(u.displayName.isNotEmpty
                                ? u.displayName.substring(0, 1)
                                : '?')),
                        title: Text(u.displayName),
                        subtitle: Text(u.email),
                        trailing: Text(u.isAdmin
                            ? '관리자'
                            : (u.isRoomOwner ? '소유자' : '일반')),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
