import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/chat_message.dart';
import '../../services/chat_repository.dart';
import '../../services/kst_time.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.session,
    required this.otherUid,
    required this.otherName,
  });

  final AppSession session;
  final String otherUid;
  final String otherName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repo = ChatRepository();
  final _controller = TextEditingController();
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    final me = widget.session.currentUser!;
    _chatId = ChatRepository.chatIdFor(me.uid, widget.otherUid);
    _repo.markRead(_chatId, me.uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final me = widget.session.currentUser!;
    _controller.clear();
    await _repo.sendMessage(
      myUid: me.uid,
      myName: me.displayName,
      otherUid: widget.otherUid,
      otherName: widget.otherName,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.session.currentUser!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _repo.watchMessages(_chatId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                      child: Text('메시지가 없습니다. 대화를 시작해보세요.',
                          style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderUid == me.uid;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(msg.text),
                            if (msg.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  KstTime.formatTimeShort(
                                      KstTime.toKst(msg.createdAt!)),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '메시지 입력',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
