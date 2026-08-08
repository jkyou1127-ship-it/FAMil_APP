import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/shopping_item.dart';
import '../../services/api_client.dart';
import '../../services/socket_service.dart';

/// 온 가족이 함께 채우고 체크하는 장보기 목록. 개인 할 일과 달리 누구나
/// 항목을 추가/체크/삭제할 수 있고, 실시간으로 서로의 변경사항이 동기화된다.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _controller = TextEditingController();
  List<ShoppingItem> _items = [];
  bool _loading = true;
  String? _error;
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = context.read<SocketService>();
    _socket.on('shopping:update', _onUpdate);
    _load();
  }

  @override
  void dispose() {
    _socket.off('shopping:update', _onUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onUpdate(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    final list = (map['items'] as List<dynamic>)
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (mounted) setState(() => _items = list);
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/shopping');
      final list = (res['items'] as List<dynamic>)
          .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _applyItemsResponse(Map<String, dynamic> res) {
    final list = (res['items'] as List<dynamic>)
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (mounted) setState(() => _items = list);
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      // 소켓 브로드캐스트만 기다리면, 재연결 대기 중일 때 내가 한 조작이
      // 내 화면에는 반영되지 않는 것처럼 보일 수 있어 응답을 바로 반영한다.
      _applyItemsResponse(await context.read<ApiClient>().post('/shopping', {'content': text}));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggle(ShoppingItem item) async {
    try {
      _applyItemsResponse(await context.read<ApiClient>().patch('/shopping/${item.id}', {'bought': !item.bought}));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(ShoppingItem item) async {
    try {
      await context.read<ApiClient>().delete('/shopping/${item.id}');
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _clearBought() async {
    try {
      await context.read<ApiClient>().delete('/shopping/bought');
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBoughtItems = _items.any((i) => i.bought);
    return Scaffold(
      appBar: AppBar(
        title: const Text('장보기 목록'),
        actions: [
          if (hasBoughtItems)
            IconButton(
              icon: const Icon(Icons.playlist_remove),
              tooltip: '산 항목 지우기',
              onPressed: _clearBought,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: '살 것을 입력하세요', border: OutlineInputBorder()),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('추가')),
              ],
            ),
          ),
          Expanded(
            child: _loading
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
                        : _items.isEmpty
                        ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Text('장보기 목록이 비어 있습니다.'))])
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (_) => _delete(item),
                                child: CheckboxListTile(
                                  value: item.bought,
                                  onChanged: (_) => _toggle(item),
                                  title: Text(
                                    item.content,
                                    style: item.bought
                                        ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                                        : null,
                                  ),
                                  subtitle: Text(
                                    item.bought ? '${item.boughtByName ?? ''}님이 구매함' : '${item.addedByName}님이 추가함',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
