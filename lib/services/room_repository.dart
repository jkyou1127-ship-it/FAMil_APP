import '../models/room.dart';
import 'api_client.dart';
import 'live_query.dart';

/// 방 및 소유자 배정을 담당한다. 소유자 배정은 관리자만 수행한다(서버에서 강제).
class RoomRepository {
  RoomRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Room>> _fetchRooms() async {
    final res = await _api.get('/rooms');
    return (res['rooms'] as List)
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<Room>> watchRooms() {
    return watchLive(fetch: _fetchRooms, event: 'rooms:changed');
  }

  Future<void> createRoom(String name) {
    return _api.post('/rooms', body: {'name': name});
  }

  Future<void> deleteRoom(String roomId) {
    return _api.delete('/rooms/$roomId');
  }

  /// 관리자가 방에 소유자를 배정한다. 기존에 다른 방을 소유하고 있었다면 서버가 해제한다.
  Future<void> assignOwner({
    required String roomId,
    required String roomName,
    required String uid,
    required String displayName,
  }) {
    return _api.post('/rooms/$roomId/assign-owner', body: {'uid': uid});
  }

  Future<void> unassignOwner({required String roomId, required String uid}) {
    return _api.post('/rooms/$roomId/unassign-owner');
  }

  Future<void> setKnockEnabled(String roomId, bool enabled) {
    return _api.patch('/rooms/$roomId', body: {'knockEnabled': enabled});
  }
}
