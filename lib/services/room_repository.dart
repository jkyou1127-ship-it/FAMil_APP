import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/room.dart';

/// 방 및 소유자 배정을 담당한다. 소유자 배정은 관리자만 수행한다.
class RoomRepository {
  RoomRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Stream<List<Room>> watchRooms() {
    return _rooms.orderBy('name').snapshots().map(
        (snap) => snap.docs.map((d) => Room.fromMap(d.id, d.data())).toList());
  }

  Future<void> createRoom(String name) async {
    await _rooms.add(Room(id: '', name: name).toMap());
  }

  Future<void> deleteRoom(String roomId) async {
    await _rooms.doc(roomId).delete();
  }

  /// 관리자가 방에 소유자를 배정한다. 기존에 다른 방을 소유하고 있었다면 해제한다.
  Future<void> assignOwner({
    required String roomId,
    required String roomName,
    required String uid,
    required String displayName,
  }) async {
    await _db.runTransaction((transaction) async {
      // 이 사용자가 이미 다른 방의 소유자였다면 그 방을 비운다.
      final prevRoomsSnap =
          await _rooms.where('ownerUid', isEqualTo: uid).get();
      for (final doc in prevRoomsSnap.docs) {
        if (doc.id != roomId) {
          transaction
              .update(doc.reference, {'ownerUid': null, 'ownerName': null});
        }
      }
      transaction.update(_rooms.doc(roomId), {
        'ownerUid': uid,
        'ownerName': displayName,
      });
      transaction.update(_users.doc(uid), {'roomId': roomId});
    });
  }

  Future<void> unassignOwner({
    required String roomId,
    required String uid,
  }) async {
    await _db.runTransaction((transaction) async {
      transaction
          .update(_rooms.doc(roomId), {'ownerUid': null, 'ownerName': null});
      transaction.update(_users.doc(uid), {'roomId': null});
    });
  }

  Future<void> setKnockEnabled(String roomId, bool enabled) {
    return _rooms.doc(roomId).update({'knockEnabled': enabled});
  }
}
