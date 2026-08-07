import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../services/chat_repository.dart';
import '../../services/kst_time.dart';
import '../../services/user_repository.dart';
import 'chat_screen.dart';

/// 온라인 매신저: 대화 목록과 새 대화 시작.
class ChatListScreen extends StatelessWidget {
  ChatListScreen({super.key, required this.session});

  final AppSession session;
  final _chatRepo = ChatRepository();
  final _userRepo = UserRepository();

  void _openChat(BuildContext context, String otherUid, String otherName) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        session: session,
        otherUid: otherUid,
        otherName: otherName,
      ),
    ));
  }

  Future<void> _pickNewChatTarget(BuildContext context) async {
    final me = session.currentUser!;
    final users = await _userRepo.fetchAllUsersOnce();
    final others = users.where((u) => u.uid != me.uid).toList();
    if (!context.mounted) return;
    final selected = await showDialog<AppUser>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('대화 상대 선택'),
        children: others
            .map((u) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, u),
                  child: Text(u.displayName),
                ))
            .toList(),
      ),
    );
    if (selected != null && context.mounted) {
      _openChat(context, selected.uid, selected.displayName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = session.currentUser!;
    return Scaffold(
      body: StreamBuilder<List<ChatSummary>>(
        stream: _chatRepo.watchMyChats(me.uid),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return const Center(
                child: Text('대화가 없습니다. 오른쪽 아래 버튼으로 새 대화를 시작하세요.',
                    style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final unread = chat.hasUnread(me.uid);
              return ListTile(
                leading: CircleAvatar(
                    child: Text(chat.otherName(me.uid).isNotEmpty
                        ? chat.otherName(me.uid).substring(0, 1)
                        : '?')),
                title: Text(chat.otherName(me.uid)),
                subtitle: Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: unread
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (chat.lastMessageAt != null)
                      Text(
                        KstTime.formatTimeShort(
                            KstTime.toKst(chat.lastMessageAt!)),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                      ),
                  ],
                ),
                onTap: () => _openChat(
                    context, chat.otherUid(me.uid), chat.otherName(me.uid)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickNewChatTarget(context),
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
