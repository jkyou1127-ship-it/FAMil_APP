import '../models/chat_message.dart';
import 'api_client.dart';
import 'live_query.dart';

/// 온라인 매신저(1:1 채팅)를 담당한다.
class ChatRepository {
  ChatRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  static String chatIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<ChatSummary>> watchMyChats(String uid) {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/chats/mine');
        return (res['chats'] as List)
            .map((e) => ChatSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      event: 'chats:changed',
    );
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/chats/$chatId/messages');
        return (res['messages'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      event: 'chats:changed',
    );
  }

  Future<void> sendMessage({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
    required String text,
  }) {
    return _api.post('/chats/$otherUid/messages', body: {'text': text});
  }

  Future<void> markRead(String chatId, String uid) {
    return _api.post('/chats/$chatId/read');
  }
}
