import 'package:sqlite3/sqlite3.dart';

/// backend/src/utils/serialize.js와 동일한 직렬화 규칙.
Map<String, dynamic>? publicUser(Row? u) {
  if (u == null) return null;
  return {
    'id': u['id'],
    'username': u['username'],
    'displayName': u['display_name'],
    'isAdmin': (u['is_admin'] as int) != 0,
    'profilePhoto': u['profile_photo'],
    'sleepStatus': u['sleep_status'],
    'sleepSoundEnabled': (u['sleep_sound_enabled'] as int) != 0,
    'sleepSoundId': u['sleep_sound_id'] ?? 'lullaby1',
    'online': (u['online'] as int) != 0,
    'roomId': u['room_id'],
    'createdAt': u['created_at'],
  };
}

Map<String, dynamic>? publicRoom(Row? r) {
  if (r == null) return null;
  return {
    'id': r['id'],
    'name': r['name'],
    'ownerId': r['owner_id'],
    'accessStatus': r['access_status'],
    'knockEnabled': r['access_status'] == 'open',
    'createdAt': r['created_at'],
  };
}
