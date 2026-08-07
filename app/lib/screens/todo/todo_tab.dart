import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/todo.dart';
import '../../services/api_client.dart';

/// 할 일 목록: 등록 -> 완료 시 취소선 + 회색 처리. 완료 후 하루가 지나면
/// 서버의 자정 정리 작업이 자동으로 삭제한다.
class TodoTab extends StatefulWidget {
  const TodoTab({super.key});

  @override
  State<TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends State<TodoTab> {
  final _controller = TextEditingController();
  List<TodoItem> _todos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/todos');
      final list = (res['todos'] as List<dynamic>)
          .map((e) => TodoItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _todos = list;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await context.read<ApiClient>().post('/todos', {'content': text});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggle(TodoItem item) async {
    try {
      await context.read<ApiClient>().patch('/todos/${item.id}', {'completed': !item.completed});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(TodoItem item) async {
    try {
      await context.read<ApiClient>().delete('/todos/${item.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: '할 일을 입력하세요', border: OutlineInputBorder()),
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
                  child: _todos.isEmpty
                      ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Text('할 일이 없습니다.'))])
                      : ListView.builder(
                          itemCount: _todos.length,
                          itemBuilder: (context, i) {
                            final item = _todos[i];
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
                                value: item.completed,
                                onChanged: (_) => _toggle(item),
                                title: Text(
                                  item.content,
                                  style: item.completed
                                      ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
