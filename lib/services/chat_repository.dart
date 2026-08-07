import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

/// 온라인 매신저(1:1 채팅)를 담당한다.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  static String chatIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<ChatSummary>> watchMyChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatSummary.fromMap(d.id, d.data())).toList());
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());
  }

  Future<void> sendMessage({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
    required String text,
  }) async {
    final chatId = chatIdFor(myUid, otherUid);
    final chatRef = _chats.doc(chatId);
    final batch = _db.batch();
    batch.set(
      chatRef,
      {
        'participants': [myUid, otherUid],
        'participantNames': {myUid: myName, otherUid: otherName},
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderUid': myUid,
      },
      SetOptions(merge: true),
    );
    batch.set(chatRef.collection('messages').doc(), ChatMessage(
      id: '',
      senderUid: myUid,
      text: text,
    ).toMap());
    await batch.commit();
  }

  Future<void> markRead(String chatId, String uid) {
    return _chats.doc(chatId).set({
      'lastReadAt': {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }
}
