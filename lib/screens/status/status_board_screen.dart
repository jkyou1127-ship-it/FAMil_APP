import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/app_user.dart';
import '../../services/kst_time.dart';
import '../../services/room_repository.dart';
import '../../services/schedule_repository.dart';
import '../../services/user_repository.dart';

/// 상태창: 프로필 사진, 출입 가능 여부, 온오프라인, 취침 여부, 오늘 일정을 보여준다.
class StatusBoardScreen extends StatefulWidget {
  const StatusBoardScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<StatusBoardScreen> createState() => _StatusBoardScreenState();
}

class _StatusBoardScreenState extends State<StatusBoardScreen> {
  final _userRepo = UserRepository();
  final _roomRepo = RoomRepository();

  @override
  Widget build(BuildContext context) {
    final me = widget.session.currentUser!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _MyStatusCard(me: me, userRepo: _userRepo, roomRepo: _roomRepo),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: _userRepo.watchAllUsers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!;
              if (users.isEmpty) {
                return const Center(child: Text('사용자가 없습니다.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _UserStatusTile(user: users[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MyStatusCard extends StatelessWidget {
  const _MyStatusCard({
    required this.me,
    required this.userRepo,
    required this.roomRepo,
  });

  final AppUser me;
  final UserRepository userRepo;
  final RoomRepository roomRepo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 상태', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (me.isRoomOwner)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('출입 가능 여부'),
                subtitle: Text(me.accessOpen
                    ? '출입 가능 (온라인 노크 활성화)'
                    : '출입 불가 (온라인 노크 비활성화)'),
                value: me.accessOpen,
                onChanged: (value) async {
                  await userRepo.setAccessOpen(me.uid, value);
                  if (me.roomId != null) {
                    await roomRepo.setKnockEnabled(me.roomId!, value);
                  }
                },
              )
            else
              const Text('※ 방 소유자로 배정되면 출입 가능 여부를 설정할 수 있습니다.',
                  style: TextStyle(color: Colors.grey)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('취침 여부'),
              subtitle: Text(me.isSleeping ? '취침 중' : '기상 상태'),
              value: me.isSleeping,
              onChanged: (value) => userRepo.setSleeping(
                me.uid,
                sleeping: value,
                sleepStartedAt: value ? DateTime.now() : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStatusTile extends StatelessWidget {
  const _UserStatusTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheduleRepo = ScheduleRepository();
    final today = KstTime.formatDate(KstTime.now());
    return Card(
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: user.profilePhotoUrl != null
                  ? NetworkImage(user.profilePhotoUrl!)
                  : null,
              child: user.profilePhotoUrl == null
                  ? Text(user.displayName.isNotEmpty
                      ? user.displayName.substring(0, 1)
                      : '?')
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.isOnline ? Colors.green : Colors.grey,
                  border:
                      Border.all(color: Theme.of(context).cardColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(user.displayName),
            const SizedBox(width: 6),
            if (user.isAdmin) const _Badge(text: '관리자', color: Colors.purple),
            if (user.isRoomOwner)
              const _Badge(text: '소유자', color: Colors.blue),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              user.accessOpen ? Icons.lock_open : Icons.lock,
              size: 14,
              color: user.accessOpen ? Colors.green : Colors.red,
            ),
            Text(user.accessOpen ? ' 출입 가능' : ' 출입 불가'),
            const SizedBox(width: 8),
            if (user.isSleeping) ...[
              const Icon(Icons.bedtime, size: 14, color: Colors.indigo),
              const Text(' 취침 중'),
            ],
          ],
        ),
        trailing: StreamBuilder(
          stream: scheduleRepo.watchScheduleForDate(user.uid, today),
          builder: (context, snapshot) {
            final list = snapshot.data;
            if (list == null || list.isEmpty) {
              return const SizedBox.shrink();
            }
            return Tooltip(
              message: list.map((s) => s.title).join(', '),
              child: const Icon(Icons.event_note, size: 20),
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
