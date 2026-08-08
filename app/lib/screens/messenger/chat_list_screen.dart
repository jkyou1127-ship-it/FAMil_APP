import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'group_chat_list_view.dart';
import 'group_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;
  late final SocketService _socket;
  late final TabController _tabController;
  final _groupListKey = GlobalKey<GroupChatListViewState>();

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('message:new', _onMessage);
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _socket.off('message:new', _onMessage);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
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
          _error = null;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      // 서버에 연결할 수 없는 경우, 이전(다른 계정일 수도 있는) 목록이 화면에
      // 그대로 남아있지 않도록 비우고 에러를 보여준다.
      if (mounted) {
        setState(() {
          _conversations = [];
          _error = e.message;
          _loading = false;
        });
      }
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

  Future<void> _createGroupRoom() async {
    final api = context.read<ApiClient>();
    final me = context.read<AuthProvider>().currentUser!;
    final res = await api.get('/users');
    final users = (res['users'] as List<dynamic>)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((u) => u.id != me.id)
        .toList();

    if (!mounted) return;
    final nameController = TextEditingController();
    final selectedIds = <int>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('단톡방 만들기'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '방 이름'),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: users
                        .map((u) => CheckboxListTile(
                              value: selectedIds.contains(u.id),
                              title: Text(u.displayName),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  selectedIds.add(u.id);
                                } else {
                                  selectedIds.remove(u.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('만들기')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty || selectedIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('방 이름과 초대할 사람을 한 명 이상 선택해주세요.')));
      return;
    }

    try {
      final res = await api.post('/chat-rooms', {'name': name, 'memberIds': selectedIds.toList()});
      _groupListKey.currentState?.load();
      final roomJson = res['room'] as Map<String, dynamic>;
      final members = [
        ChatRoomMember(id: me.id, displayName: me.displayName),
        ...users.where((u) => selectedIds.contains(u.id)).map((u) => ChatRoomMember(id: u.id, displayName: u.displayName)),
      ];
      final room = ChatRoom(
        id: roomJson['id'] as int,
        name: roomJson['name'] as String,
        createdBy: roomJson['createdBy'] as int,
        createdAt: roomJson['createdAt'] as String,
        members: members,
        lastMessage: null,
        unreadCount: 0,
      );
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupChatScreen(room: room)));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroupTab = _tabController.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('매신저'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '1:1'), Tab(text: '단톡방')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isGroupTab ? _createGroupRoom : _pickNewConversation,
        child: Icon(isGroupTab ? Icons.group_add_outlined : Icons.add_comment_outlined),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _error != null
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text('서버에 연결할 수 없습니다: $_error\n아래로 당겨서 다시 시도해주세요.'),
                            ),
                          ],
                        )
                      : _conversations.isEmpty
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
                              leading:
                                  UserAvatar(photoUrl: c.partnerPhoto, name: c.partnerName, online: c.partnerOnline),
                              title: Text(c.partnerName),
                              subtitle: Text(
                                c.lastMessage?.content ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: c.unreadCount > 0
                                  ? CircleAvatar(
                                      radius: 10, child: Text('${c.unreadCount}', style: const TextStyle(fontSize: 11)))
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
          GroupChatListView(key: _groupListKey),
        ],
      ),
    );
  }
}
