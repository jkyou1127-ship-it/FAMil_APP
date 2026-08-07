import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/knock.dart';
import '../../models/room.dart';
import '../../services/knock_repository.dart';
import '../../services/room_repository.dart';

/// 온라인 노크: 방을 클릭하면 소유자에게 알림이 가고,
/// 소유자가 승인하면 요청자에게 알림이 간다.
class KnockScreen extends StatelessWidget {
  KnockScreen({super.key, required this.session});

  final AppSession session;
  final _roomRepo = RoomRepository();
  final _knockRepo = KnockRepository();

  @override
  Widget build(BuildContext context) {
    final me = session.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (me.isRoomOwner) ...[
          Text('나에게 온 노크 요청', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<Knock>>(
            stream: _knockRepo.watchIncomingKnocks(me.uid),
            builder: (context, snapshot) {
              final knocks = snapshot.data ?? [];
              if (knocks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('대기 중인 노크 요청이 없습니다.',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: knocks
                    .map((k) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.front_hand),
                            title: Text('${k.requesterName}님이 노크했습니다'),
                            subtitle: Text(k.roomName),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  onPressed: () => _knockRepo.respond(k.id,
                                      approve: true),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.red),
                                  onPressed: () => _knockRepo.respond(k.id,
                                      approve: false),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        Text('방 목록', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<List<Room>>(
          stream: _roomRepo.watchRooms(),
          builder: (context, snapshot) {
            final rooms = snapshot.data ?? [];
            if (rooms.isEmpty) {
              return const Text('등록된 방이 없습니다. 관리자에게 문의하세요.',
                  style: TextStyle(color: Colors.grey));
            }
            return Column(
              children: rooms.map((room) {
                final isMine = room.ownerUid == me.uid;
                final noOwner = room.ownerUid == null;
                final canKnock =
                    !isMine && !noOwner && room.knockEnabled;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.meeting_room),
                    title: Text(room.name),
                    subtitle: Text(noOwner
                        ? '소유자 미배정'
                        : '소유자: ${room.ownerName ?? ''}'
                            '${room.knockEnabled ? '' : ' · 출입 불가'}'),
                    trailing: isMine
                        ? const Chip(label: Text('내 방'))
                        : ElevatedButton(
                            onPressed: canKnock
                                ? () async {
                                    await _knockRepo.sendKnock(
                                      roomId: room.id,
                                      roomName: room.name,
                                      requesterUid: me.uid,
                                      requesterName: me.displayName,
                                      ownerUid: room.ownerUid!,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('노크했습니다.')),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('노크하기'),
                          ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
