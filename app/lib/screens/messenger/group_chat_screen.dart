import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../widgets/user_avatar.dart';

class GroupChatScreen extends StatefulWidget {
  final ChatRoom room;
  const GroupChatScreen({super.key, required this.room});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<GroupMessage> _messages = [];
  bool _loading = true;
  String? _error;
  late final SocketService _socket;
  late final int _meId;

  @override
  void initState() {
    super.initState();
    _meId = context.read<AuthProvider>().currentUser!.id;
    _socket = context.read<SocketService>();
    _socket.on('group:message:new', _onMessage);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _socket.off('group:message:new', _onMessage);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _onMessage(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    if (map['roomId'] == widget.room.id) _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/chat-rooms/${widget.room.id}/messages');
      final list = (res['messages'] as List<dynamic>)
          .map((e) => GroupMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _messages = list;
          _error = null;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _messages = [];
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _socket.emit('group:message:send', {'roomId': widget.room.id, 'content': text}, (response) {
      final map = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      if (map['error'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(map['error'].toString())));
      }
    });
  }

  Future<void> _invite() async {
    final api = context.read<ApiClient>();
    final res = await api.get('/users');
    final memberIds = widget.room.members.map((m) => m.id).toSet();
    final users = (res['users'] as List<dynamic>)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((u) => !memberIds.contains(u.id))
        .toList();

    if (!mounted) return;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('초대할 수 있는 사용자가 없습니다.')));
      return;
    }

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

    if (selected == null || !mounted) return;
    try {
      await api.post('/chat-rooms/${widget.room.id}/members', {'userId': selected.id});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${selected.displayName}님을 초대했습니다.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단톡방 나가기'),
        content: Text('"${widget.room.name}" 방에서 나가시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('나가기')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().delete('/chat-rooms/${widget.room.id}/members/me');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_outlined), onPressed: _invite, tooltip: '멤버 초대'),
          IconButton(icon: const Icon(Icons.logout), onPressed: _leave, tooltip: '나가기'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('서버에 연결할 수 없습니다: $_error', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.senderId == _meId;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!mine)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    m.senderName ?? '',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Text(m.content),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('HH:mm').format(DateTime.parse(m.createdAt).toLocal()),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: '메시지를 입력하세요', border: OutlineInputBorder()),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
