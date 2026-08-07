import 'package:flutter/material.dart';

import '../../app_session.dart';
import '../../models/todo_item.dart';
import '../../services/todo_repository.dart';

/// 할 일 목록: 등록하면 목록에 추가되고, 완료를 누르면 취소선+회색으로 표시된다.
/// 완료된 지 하루가 지난 항목은 자동으로 삭제된다.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _repo = TodoRepository();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo.cleanupStaleDoneTodos(widget.session.currentUser!.uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _repo.addTodo(widget.session.currentUser!.uid, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.session.currentUser!.uid;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '할 일을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _add,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TodoItem>>(
            stream: _repo.watchMyTodos(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final todos = snapshot.data!;
              if (todos.isEmpty) {
                return const Center(
                    child: Text('할 일이 없습니다.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final todo = todos[index];
                  return CheckboxListTile(
                    value: todo.done,
                    onChanged: (value) =>
                        _repo.setDone(todo.id, value ?? false),
                    title: Text(
                      todo.text,
                      style: todo.done
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey)
                          : null,
                    ),
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _repo.deleteTodo(todo.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
