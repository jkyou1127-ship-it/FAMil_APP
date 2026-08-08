function publicUser(u) {
  if (!u) return null;
  return {
    id: u.id,
    username: u.username,
    displayName: u.display_name,
    isAdmin: !!u.is_admin,
    profilePhoto: u.profile_photo,
    sleepStatus: u.sleep_status,
    sleepSoundEnabled: !!u.sleep_sound_enabled,
    sleepSoundId: u.sleep_sound_id || 'lullaby1',
    online: !!u.online,
    roomId: u.room_id,
    createdAt: u.created_at,
  };
}

function publicRoom(r) {
  if (!r) return null;
  return {
    id: r.id,
    name: r.name,
    ownerId: r.owner_id,
    accessStatus: r.access_status,
    knockEnabled: r.access_status === 'open',
    createdAt: r.created_at,
  };
}

module.exports = { publicUser, publicRoom };
