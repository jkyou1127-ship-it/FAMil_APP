export function serializeUser(row) {
  if (!row) return null;
  return {
    uid: row.id,
    email: row.email,
    displayName: row.display_name,
    role: row.role,
    roomId: row.room_id,
    isOnline: !!row.is_online,
    accessOpen: !!row.access_open,
    isSleeping: !!row.is_sleeping,
    sleepStartedAt: row.sleep_started_at,
    sleepMusicEnabled: !!row.sleep_music_enabled,
    profilePhotoUrl: row.profile_photo_url,
    createdAt: row.created_at,
  };
}

export function serializeRoom(row) {
  return {
    id: row.id,
    name: row.name,
    ownerUid: row.owner_uid,
    ownerName: row.owner_name,
    knockEnabled: !!row.knock_enabled,
  };
}

export function serializeKnock(row) {
  return {
    id: row.id,
    roomId: row.room_id,
    roomName: row.room_name,
    requesterUid: row.requester_uid,
    requesterName: row.requester_name,
    ownerUid: row.owner_uid,
    status: row.status,
    createdAt: row.created_at,
    respondedAt: row.responded_at,
    requesterAcknowledged: !!row.requester_acknowledged,
  };
}

export function serializeTodo(row) {
  return {
    id: row.id,
    uid: row.uid,
    text: row.text,
    done: !!row.done,
    createdAt: row.created_at,
    doneAt: row.done_at,
  };
}

export function serializeSchedule(row) {
  return {
    id: row.id,
    uid: row.uid,
    ownerName: row.owner_name,
    date: row.date,
    title: row.title,
    memo: row.memo,
    createdAt: row.created_at,
  };
}

export function serializeSuggestion(row) {
  return { id: row.id, text: row.text, createdAt: row.created_at };
}

export function serializeChat(row) {
  return {
    id: row.id,
    participants: JSON.parse(row.participants),
    participantNames: JSON.parse(row.participant_names),
    lastMessage: row.last_message || '',
    lastMessageAt: row.last_message_at,
    lastSenderUid: row.last_sender_uid,
    lastReadAt: JSON.parse(row.last_read_at || '{}'),
  };
}

export function serializeMessage(row) {
  return {
    id: row.id,
    senderUid: row.sender_uid,
    text: row.text,
    createdAt: row.created_at,
  };
}

export function serializeDraw(row) {
  return {
    id: row.id,
    title: row.title,
    participantUids: JSON.parse(row.participant_uids),
    participantNames: JSON.parse(row.participant_names),
    winnerUid: row.winner_uid,
    winnerName: row.winner_name,
    createdByUid: row.created_by_uid,
    createdAt: row.created_at,
  };
}

export function serializeSleepSession(row) {
  return {
    id: row.id,
    uid: row.uid,
    sleptAt: row.slept_at,
    wokeAt: row.woke_at,
  };
}

export function serializeAlarm(row) {
  return {
    id: row.id,
    uid: row.uid,
    label: row.label,
    hour: row.hour,
    minute: row.minute,
    repeat: row.repeat,
    weekdays: JSON.parse(row.weekdays || '[]'),
    onceDate: row.once_date,
    soundId: row.sound_id,
    customSoundPath: row.custom_sound_path,
    enabled: !!row.enabled,
  };
}
