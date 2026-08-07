import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('message:new', _onMessage);
    _load();
  }

  @override
  void dispose() {
    _socket.off('message:new', _onMessage);
    super.dispose();
  }

  void _onMessage(dynamic _) => _load();

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/messages/conversations');
      final list = (res['conversations'] as List<dynamic>)
          .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickNewConversation() async {
    final api = context.read<ApiClient>();
    final me = context.read<AuthProvider>().currentUser!;
    final res = await api.get('/users');
    final users = (res['users'] as List<dynamic>)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((u) => u.id != me.id)
        .toList();

    if (!mounted) return;
    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: users
              .map((u) => ListTile(
                    leading: UserAvatar(photoUrl: u.profilePhoto, name: u.displayName, online: u.online),
                    title: Text(u.displayName),
                    onTap: () => Navigator.of(context).pop(u),
                  ))
              .toList(),
        ),
      ),
    );

    if (selected != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(partnerId: selected.id, partnerName: selected.displayName)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('매신저')),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickNewConversation,
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _conversations.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('대화가 없습니다. 우측 하단 버튼으로 새 대화를 시작해보세요.'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, i) {
                        final c = _conversations[i];
                        return ListTile(
                          leading: UserAvatar(photoUrl: c.partnerPhoto, name: c.partnerName, online: c.partnerOnline),
                          title: Text(c.partnerName),
                          subtitle: Text(
                            c.lastMessage?.content ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: c.unreadCount > 0
                              ? CircleAvatar(radius: 10, child: Text('${c.unreadCount}', style: const TextStyle(fontSize: 11)))
                              : null,
                          onTap: () {
                            if (c.partnerId == null) return;
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                  builder: (_) => ChatScreen(partnerId: c.partnerId!, partnerName: c.partnerName),
                                ))
                                .then((_) => _load());
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
