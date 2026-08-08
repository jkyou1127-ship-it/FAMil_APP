import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/message.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/socket_service.dart';

class ChatScreen extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  const ChatScreen({super.key, required this.partnerId, required this.partnerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  late final SocketService _socket;
  late final int _meId;

  @override
  void initState() {
    super.initState();
    _meId = context.read<AuthProvider>().currentUser!.id;
    _socket = context.read<SocketService>();
    _socket.on('message:new', _onMessage);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _socket.off('message:new', _onMessage);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에 있는 동안 소켓이 끊겼다가 늦게 재연결되는 경우를 대비해,
    // 앱으로 돌아올 때마다 대화 내용을 새로 불러온다.
    if (state == AppLifecycleState.resumed) _load();
  }

  void _onMessage(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    final belongsHere = (map['senderId'] == widget.partnerId && map['receiverId'] == _meId) ||
        (map['senderId'] == _meId && map['receiverId'] == widget.partnerId);
    if (belongsHere) _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/messages/${widget.partnerId}');
      final list = (res['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
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
      // 서버에 연결할 수 없는 경우, 이전(다른 계정일 수도 있는) 대화 내용이
      // 화면에 그대로 남아있지 않도록 비우고 에러를 보여준다.
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
    _socket.emit('message:send', {'receiverId': widget.partnerId, 'content': text}, (response) {
      final map = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      if (map['error'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(map['error'].toString())));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.partnerName)),
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
