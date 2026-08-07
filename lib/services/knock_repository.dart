import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/knock.dart';

class KnockRepository {
  KnockRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _knocks =>
      _db.collection('knocks');

  /// 요청자가 방을 노크하면 소유자에게 전달될 알림 문서를 생성한다.
  Future<void> sendKnock({
    required String roomId,
    required String roomName,
    required String requesterUid,
    required String requesterName,
    required String ownerUid,
  }) async {
    await _knocks.add(Knock(
      id: '',
      roomId: roomId,
      roomName: roomName,
      requesterUid: requesterUid,
      requesterName: requesterName,
      ownerUid: ownerUid,
    ).toMap());
  }

  /// 소유자에게 온 대기 중인 노크 목록(실시간 알림용).
  Stream<List<Knock>> watchIncomingKnocks(String ownerUid) {
    return _knocks
        .where('ownerUid', isEqualTo: ownerUid)
        .where('status', isEqualTo: KnockStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Knock.fromMap(d.id, d.data())).toList());
  }

  /// 요청자에게 온 응답(승인/거절) 중 아직 확인하지 않은 알림.
  Stream<List<Knock>> watchMyResponses(String requesterUid) {
    return _knocks
        .where('requesterUid', isEqualTo: requesterUid)
        .where('status', whereIn: [
          KnockStatus.approved.name,
          KnockStatus.denied.name,
        ])
        .where('requesterAcknowledged', isEqualTo: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Knock.fromMap(d.id, d.data())).toList());
  }

  Future<void> respond(String knockId, {required bool approve}) {
    return _knocks.doc(knockId).update({
      'status':
          (approve ? KnockStatus.approved : KnockStatus.denied).name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acknowledge(String knockId) {
    return _knocks.doc(knockId).update({'requesterAcknowledged': true});
  }
}
