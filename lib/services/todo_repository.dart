import '../models/todo_item.dart';
import 'api_client.dart';
import 'live_query.dart';

class TodoRepository {
  TodoRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<TodoItem>> _fetchMine() async {
    final res = await _api.get('/todos');
    return (res['todos'] as List)
        .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<TodoItem>> watchMyTodos(String uid) {
    return watchLive(fetch: _fetchMine, event: 'todos:changed');
  }

  Future<void> addTodo(String uid, String text) {
    return _api.post('/todos', body: {'text': text});
  }

  Future<void> setDone(String todoId, bool done) {
    return _api.patch('/todos/$todoId', body: {'done': done});
  }

  Future<void> deleteTodo(String todoId) {
    return _api.delete('/todos/$todoId');
  }

  /// 완료된 지 하루가 지난 할 일 삭제는 서버가 GET /todos 때마다 자동으로
  /// 처리한다. 화면 진입 시 한 번 미리 불러와 정리해 둔다.
  Future<void> cleanupStaleDoneTodos(String uid) => _fetchMine();
}
