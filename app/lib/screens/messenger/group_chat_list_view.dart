import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room.dart';
import '../../services/api_client.dart';
import '../../services/socket_service.dart';
import 'group_chat_screen.dart';

class GroupChatListView extends StatefulWidget {
  const GroupChatListView({super.key});

  @override
  State<GroupChatListView> createState() => GroupChatListViewState();
}

class GroupChatListViewState extends State<GroupChatListView> with WidgetsBindingObserver {
  List<ChatRoom> _rooms = [];
  bool _loading = true;
  String? _error;
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('group:message:new', _onUpdate);
    _socket.on('group:room:new', _onUpdate);
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    _socket.off('group:message:new', _onUpdate);
    _socket.off('group:room:new', _onUpdate);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  void _onUpdate(dynamic _) => load();

  Future<void> load() async {
    try {
      final res = await context.read<ApiClient>().get('/chat-rooms');
      final list = (res['rooms'] as List<dynamic>)
          .map((e) => ChatRoom.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _rooms = list;
          _error = null;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _rooms = [];
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: _error != null
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('서버에 연결할 수 없습니다: $_error\n아래로 당겨서 다시 시도해주세요.'),
                ),
              ],
            )
          : _rooms.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('참여 중인 단톡방이 없습니다. 우측 하단 버튼으로 만들어보세요.'),
                ),
              ],
            )
          : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (context, i) {
                final r = _rooms[i];
                final preview = r.lastMessage != null
                    ? '${r.lastMessage!.senderName ?? ''}: ${r.lastMessage!.content}'
                    : '${r.members.length}명 참여 중';
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                  title: Text(r.name),
                  subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: r.unreadCount > 0
                      ? CircleAvatar(radius: 10, child: Text('${r.unreadCount}', style: const TextStyle(fontSize: 11)))
                      : null,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => GroupChatScreen(room: r)))
                      .then((_) => load()),
                );
              },
            ),
    );
  }
}
