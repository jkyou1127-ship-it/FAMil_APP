/*
 * End-to-end smoke test for the FAMil APP backend.
 * Starts the server in-process against a throwaway SQLite file, exercises
 * every route + socket flow, and exits non-zero on the first failure.
 * Usage: npm run smoketest
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

const dbPath = path.join(os.tmpdir(), `famil-smoketest-${Date.now()}.db`);
process.env.DB_PATH = dbPath;
process.env.JWT_SECRET = 'smoketest-secret';
process.env.PORT = '4501';

const { server } = require('../server');
const WebSocket = require('ws');

const BASE = 'http://localhost:4501';
let failures = 0;

function assert(cond, msg) {
  if (!cond) {
    failures += 1;
    console.error(`✗ FAIL: ${msg}`);
  } else {
    console.log(`✓ ${msg}`);
  }
}

async function api(method, urlPath, { token, body } = {}) {
  const res = await fetch(`${BASE}${urlPath}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try {
    json = await res.json();
  } catch (e) {
    /* no body */
  }
  return { status: res.status, json };
}

// Socket.IO client 대신 raw WebSocket으로 실시간 프로토콜을 직접 구사한다
// (backend/src/sockets/ws_hub.js와 동일한 {event, data} 봉투).
function connectSocket(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:4501/realtime?token=${encodeURIComponent(token)}`);
    const onceHandlers = new Map();

    ws.on('message', (raw) => {
      let message;
      try {
        message = JSON.parse(raw.toString());
      } catch (err) {
        return;
      }
      const handlers = onceHandlers.get(message.event);
      if (handlers && handlers.length) handlers.shift()(message.data);
    });

    ws.once('open', () => {
      resolve({
        once(event, cb) {
          if (!onceHandlers.has(event)) onceHandlers.set(event, []);
          onceHandlers.get(event).push(cb);
        },
        emit(event, data) {
          ws.send(JSON.stringify({ event, data }));
        },
        close() {
          ws.close();
        },
      });
    });
    ws.once('error', reject);
  });
}

async function main() {
  // ---- Register: first user becomes admin ----
  let r = await api('POST', '/auth/register', {
    body: { username: 'admin1', password: 'pass1234', displayName: '관리자' },
  });
  assert(r.status === 201 && r.json.user.isAdmin === true, '첫 계정은 자동으로 관리자가 된다');
  const adminToken = r.json.token;
  const adminId = r.json.user.id;

  r = await api('POST', '/auth/register', {
    body: { username: 'owner1', password: 'pass1234', displayName: '철수' },
  });
  assert(r.status === 201 && r.json.user.isAdmin === false, '두번째 계정은 관리자가 아니다');
  const ownerToken = r.json.token;
  const ownerId = r.json.user.id;

  r = await api('POST', '/auth/register', {
    body: { username: 'guest1', password: 'pass1234', displayName: '영희' },
  });
  const guestToken = r.json.token;
  const guestId = r.json.user.id;

  r = await api('POST', '/auth/login', { body: { username: 'admin1', password: 'pass1234' } });
  assert(r.status === 200 && r.json.token, '로그인 성공');

  r = await api('POST', '/auth/login', { body: { username: 'admin1', password: 'wrong' } });
  assert(r.status === 401, '잘못된 비밀번호는 거부된다');

  // ---- Rooms & owner assignment (admin only) ----
  r = await api('POST', '/rooms', { token: guestToken, body: { name: '해킹시도' } });
  assert(r.status === 403, '관리자가 아니면 방을 만들 수 없다');

  r = await api('POST', '/rooms', { token: adminToken, body: { name: '철수방' } });
  assert(r.status === 201, '관리자는 방을 만들 수 있다');
  const roomId = r.json.room.id;

  r = await api('POST', `/rooms/${roomId}/assign-owner`, { token: adminToken, body: { userId: ownerId } });
  assert(r.status === 200 && r.json.room.ownerId === ownerId, '관리자가 소유자를 배정한다');

  r = await api('PATCH', `/rooms/${roomId}/name`, { token: ownerToken, body: { name: '해킹시도' } });
  assert(r.status === 403, '관리자가 아니면 방 이름을 바꿀 수 없다');
  r = await api('PATCH', `/rooms/${roomId}/name`, { token: adminToken, body: { name: '철수의방' } });
  assert(r.status === 200 && r.json.room.name === '철수의방', '관리자가 방 이름을 변경한다');

  // ---- Sockets: presence + knock + messenger ----
  const ownerSocket = await connectSocket(ownerToken);
  const guestSocket = await connectSocket(guestToken);
  await new Promise((res) => setTimeout(res, 200));

  r = await api('GET', '/status', { token: adminToken });
  const ownerStatus = r.json.board.find((b) => b.userId === ownerId);
  assert(ownerStatus.online === true, '소켓 연결 시 온라인 상태로 표시된다');

  const knockPromise = new Promise((resolve) => ownerSocket.once('knock:new', resolve));
  r = await api('POST', `/rooms/${roomId}/knock`, { token: guestToken });
  assert(r.status === 201, '요청자가 노크를 보낸다');
  const knockEvent = await knockPromise;
  assert(knockEvent.roomId === roomId, '소유자가 실시간으로 노크 알림을 받는다');

  const respondPromise = new Promise((resolve) => guestSocket.once('knock:responded', resolve));
  r = await api('POST', `/rooms/knocks/${knockEvent.id}/respond`, {
    token: ownerToken,
    body: { approve: true },
  });
  assert(r.status === 200 && r.json.knock.status === 'approved', '소유자가 노크를 승인한다');
  const responded = await respondPromise;
  assert(responded.status === 'approved', '요청자가 실시간으로 승인 알림을 받는다');

  // access off -> knock disabled
  r = await api('PATCH', `/rooms/${roomId}/access`, { token: ownerToken, body: { status: 'closed' } });
  assert(r.status === 200 && r.json.room.knockEnabled === false, '소유자가 출입을 막으면 노크가 비활성화된다');
  r = await api('POST', `/rooms/${roomId}/knock`, { token: guestToken });
  assert(r.status === 403, '출입 제한 시 노크가 거부된다');
  await api('PATCH', `/rooms/${roomId}/access`, { token: ownerToken, body: { status: 'open' } });

  // messenger via socket
  const messagePromise = new Promise((resolve) => ownerSocket.once('message:new', resolve));
  guestSocket.emit('message:send', { receiverId: ownerId, content: '안녕하세요!' });
  const msg = await messagePromise;
  assert(msg.content === '안녕하세요!', '소켓으로 실시간 메시지가 전달된다');

  r = await api('GET', `/messages/${guestId}`, { token: ownerToken });
  assert(r.json.messages.some((m) => m.content === '안녕하세요!'), 'REST로 대화 내역을 조회할 수 있다');

  // ---- Account deletion ----
  r = await api('DELETE', '/users/me', { token: adminToken, body: { password: 'pass1234' } });
  assert(r.status === 403, '관리자 계정은 탈퇴할 수 없다');
  r = await api('DELETE', '/users/me', { token: guestToken, body: { password: 'wrongpass' } });
  assert(r.status === 401, '비밀번호가 틀리면 탈퇴가 거부된다');
  r = await api('POST', '/auth/register', {
    body: { username: 'temp1', password: 'pass1234', displayName: '임시' },
  });
  const tempToken = r.json.token;
  r = await api('DELETE', '/users/me', { token: tempToken, body: { password: 'pass1234' } });
  assert(r.status === 204, '본인 계정은 비밀번호 확인 후 탈퇴할 수 있다');
  r = await api('POST', '/auth/login', { body: { username: 'temp1', password: 'pass1234' } });
  assert(r.status === 401, '탈퇴한 계정으로는 로그인할 수 없다');

  // ---- Password & username change ----
  r = await api('POST', '/auth/register', {
    body: { username: 'temp2', password: 'pass1234', displayName: '임시2' },
  });
  const temp2Token = r.json.token;
  r = await api('PATCH', '/users/me/password', {
    token: temp2Token,
    body: { currentPassword: 'wrongpass', newPassword: 'newpass1' },
  });
  assert(r.status === 401, '현재 비밀번호가 틀리면 비밀번호 변경이 거부된다');
  r = await api('PATCH', '/users/me/password', {
    token: temp2Token,
    body: { currentPassword: 'pass1234', newPassword: 'newpass1' },
  });
  assert(r.status === 204, '현재 비밀번호 확인 후 비밀번호를 변경할 수 있다');
  r = await api('POST', '/auth/login', { body: { username: 'temp2', password: 'newpass1' } });
  assert(r.status === 200, '변경된 비밀번호로 로그인할 수 있다');

  r = await api('PATCH', '/users/me/username', {
    token: temp2Token,
    body: { newUsername: 'owner1', password: 'newpass1' },
  });
  assert(r.status === 409, '이미 사용 중인 아이디로는 변경할 수 없다');
  r = await api('PATCH', '/users/me/username', {
    token: temp2Token,
    body: { newUsername: 'temp2renamed', password: 'newpass1' },
  });
  assert(r.status === 200 && r.json.user.username === 'temp2renamed', '아이디를 변경할 수 있다');
  r = await api('POST', '/auth/login', { body: { username: 'temp2renamed', password: 'newpass1' } });
  assert(r.status === 200, '변경된 아이디로 로그인할 수 있다');

  // ---- Suggestions (anonymous, visible to all) ----
  r = await api('POST', '/suggestions', { token: guestToken, body: { content: '건조기 사주세요' } });
  assert(r.status === 201 && r.json.suggestion.authorId === undefined, '건의사항은 작성자 정보 없이 저장된다');
  r = await api('GET', '/suggestions', { token: ownerToken });
  assert(r.json.suggestions.some((s) => s.content === '건조기 사주세요'), '모두가 건의사항을 볼 수 있다');

  // ---- Group chat (단톡방) ----
  r = await api('POST', '/chat-rooms', {
    token: ownerToken,
    body: { name: '가족방', memberIds: [guestId] },
  });
  assert(r.status === 201 && r.json.room.name === '가족방', '단톡방을 만들 수 있다');
  const chatRoomId = r.json.room.id;

  r = await api('GET', '/chat-rooms', { token: guestToken });
  assert(
    r.json.rooms.some((rm) => rm.id === chatRoomId && rm.members.length === 2),
    '멤버는 자신이 속한 단톡방 목록을 볼 수 있다'
  );

  r = await api('POST', `/chat-rooms/${chatRoomId}/messages`, {
    token: ownerToken,
    body: { content: 'REST로 보낸 메시지' },
  });
  assert(r.status === 201, 'REST로 단톡방 메시지를 보낼 수 있다');

  const groupMessagePromise = new Promise((resolve) => guestSocket.once('group:room:new', resolve));
  r = await api('POST', '/chat-rooms', { token: adminToken, body: { name: '관리자방', memberIds: [guestId] } });
  const inviteNotice = await groupMessagePromise;
  assert(inviteNotice.name === '관리자방', '단톡방에 초대되면 실시간으로 알림을 받는다');

  const socketMessagePromise = new Promise((resolve) => ownerSocket.once('group:message:new', resolve));
  guestSocket.emit('group:message:send', { roomId: chatRoomId, content: '소켓으로 보낸 메시지' });
  const groupMsg = await socketMessagePromise;
  assert(groupMsg.content === '소켓으로 보낸 메시지', '단톡방 멤버가 실시간으로 메시지를 받는다');

  r = await api('GET', `/chat-rooms/${chatRoomId}/messages`, { token: guestToken });
  assert(
    r.json.messages.some((m) => m.content === '소켓으로 보낸 메시지'),
    'REST로 단톡방 대화 내역을 조회할 수 있다'
  );

  r = await api('DELETE', `/chat-rooms/${chatRoomId}/members/me`, { token: guestToken });
  assert(r.status === 204, '단톡방을 나갈 수 있다');
  r = await api('GET', '/chat-rooms', { token: guestToken });
  assert(!r.json.rooms.some((rm) => rm.id === chatRoomId), '나간 단톡방은 더 이상 목록에 보이지 않는다');

  // ---- Backup: 스냅샷 + merge-import (관리자가 아니어도 누구나 폰을 백업 서버로 쓸 수 있어야 한다) ----
  r = await api('GET', '/backup/meta', { token: guestToken });
  assert(r.status === 200 && typeof r.json.maxUserId === 'number', '관리자가 아니어도 백업 기준값을 조회할 수 있다');

  const snapshotRes = await fetch(`${BASE}/backup/snapshot`, {
    headers: { Authorization: `Bearer ${guestToken}` },
  });
  const snapshotBytes = await snapshotRes.arrayBuffer();
  assert(snapshotRes.status === 200 && snapshotBytes.byteLength > 0, '관리자가 아니어도 백업 스냅샷 파일을 내려받을 수 있다');

  r = await api('GET', '/todos', { token: guestToken });
  const todosBeforeMerge = r.json.todos.length;
  r = await api('POST', '/backup/merge-import', {
    token: guestToken,
    body: {
      todos: [{ userId: guestId, content: '병합된 할일', completed: false, createdAt: new Date().toISOString() }],
      suggestions: [{ content: '병합된 건의사항', createdAt: new Date().toISOString() }],
    },
  });
  assert(r.status === 200 && r.json.imported.todos === 1 && r.json.imported.suggestions === 1, '관리자가 아니어도 백업 서버의 새 데이터를 주 서버로 병합할 수 있다');
  r = await api('GET', '/todos', { token: guestToken });
  assert(r.json.todos.length === todosBeforeMerge + 1, '병합된 할일이 실제로 반영된다');

  // ---- 장보기 목록 (온 가족이 함께 씀) ----
  r = await api('POST', '/shopping', { token: guestToken, body: { content: '우유' } });
  assert(r.status === 201 && r.json.items.some((i) => i.content === '우유'), '아무나 장보기 목록에 항목을 추가할 수 있다');
  r = await api('GET', '/shopping', { token: ownerToken });
  const shoppingItem = r.json.items.find((i) => i.content === '우유');
  assert(shoppingItem && shoppingItem.bought === false, '다른 사용자도 장보기 목록을 볼 수 있다');

  r = await api('PATCH', `/shopping/${shoppingItem.id}`, { token: ownerToken, body: { bought: true } });
  assert(r.status === 200 && r.json.items.find((i) => i.id === shoppingItem.id).bought === true, '다른 사용자가 추가한 항목도 산 것으로 체크할 수 있다');

  r = await api('DELETE', '/shopping/bought', { token: guestToken });
  assert(r.status === 204, '산 항목을 한 번에 정리할 수 있다');
  r = await api('GET', '/shopping', { token: guestToken });
  assert(!r.json.items.some((i) => i.id === shoppingItem.id), '정리된 항목은 목록에서 사라진다');

  // ---- Sleep / wake ----
  r = await api('POST', '/sleep/start', { token: guestToken });
  assert(r.status === 201, '취침 기록이 생성된다');
  r = await api('POST', '/sleep/start', { token: guestToken });
  assert(r.status === 409, '이미 취침 중이면 다시 취침할 수 없다');
  r = await api('POST', '/sleep/wake', { token: guestToken });
  assert(r.status === 200 && r.json.record.durationMinutes >= 0, '기상 시 잔 시간이 계산된다');
  r = await api('PATCH', '/sleep/sound', { token: guestToken, body: { enabled: false } });
  assert(r.status === 200 && r.json.sleepSoundEnabled === false, '수면 유도 노래 off 설정이 저장된다');
  r = await api('PATCH', '/sleep/sound', { token: guestToken, body: { enabled: true, soundId: 'lullaby2' } });
  assert(r.status === 200 && r.json.sleepSoundId === 'lullaby2', '수면 유도 노래 곡을 선택할 수 있다');
  r = await api('GET', '/auth/me', { token: guestToken });
  assert(r.json.user.sleepSoundId === 'lullaby2', '선택한 곡이 프로필에 반영된다');

  // ---- 취침 시 자동 출입금지 ----
  const roomAccess = async () => {
    const res = await api('GET', '/rooms', { token: ownerToken });
    return res.json.rooms.find((rm) => rm.id === roomId).accessStatus;
  };
  await api('POST', '/sleep/start', { token: ownerToken });
  assert((await roomAccess()) === 'closed', '취침하면 소유한 방이 자동으로 출입금지로 바뀐다');
  await api('POST', '/sleep/wake', { token: ownerToken });
  assert((await roomAccess()) === 'open', '기상하면 취침으로 닫혔던 방이 자동으로 다시 열린다');

  await api('PATCH', `/rooms/${roomId}/access`, { token: ownerToken, body: { status: 'closed' } });
  await api('POST', '/sleep/start', { token: ownerToken });
  await api('POST', '/sleep/wake', { token: ownerToken });
  assert((await roomAccess()) === 'closed', '수동으로 닫아둔 방은 기상해도 자동으로 열리지 않는다');
  await api('PATCH', `/rooms/${roomId}/access`, { token: ownerToken, body: { status: 'open' } });

  // ---- Alarms ----
  r = await api('POST', '/alarms', {
    token: guestToken,
    body: { time: '07:30', repeatType: 'weekly', repeatDays: [1, 2, 3, 4, 5], sound: 'tone1' },
  });
  assert(r.status === 201, '요일별 반복 알람을 만들 수 있다');
  r = await api('POST', '/alarms', { token: guestToken, body: { time: '99:99', repeatType: 'daily' } });
  assert(r.status === 400, '잘못된 시간 형식은 거부된다');

  // ---- Schedules ----
  r = await api('POST', '/schedules', { token: guestToken, body: { date: '2026-08-10', content: '병원 예약' } });
  assert(r.status === 201, '일정을 등록할 수 있다');

  // ---- Todos: complete -> strikethrough flag -> cron cleanup ----
  r = await api('POST', '/todos', { token: guestToken, body: { content: '설거지' } });
  const todoId = r.json.todo.id;
  r = await api('PATCH', `/todos/${todoId}`, { token: guestToken, body: { completed: true } });
  assert(r.status === 200 && r.json.todo.completed === true && r.json.todo.completedDate, '할 일 완료 처리 및 완료일 기록');

  const { cleanupCompletedTodos } = require('../cron');
  const db = require('../db');
  db.prepare('UPDATE todos SET completed_date = ? WHERE id = ?').run('2000-01-01', todoId);
  cleanupCompletedTodos();
  r = await api('GET', '/todos', { token: guestToken });
  assert(!r.json.todos.some((t) => t.id === todoId), '하루가 지난 완료 항목은 자정 정리 작업으로 삭제된다');

  // ---- Status board reflects room + sleep + online ----
  r = await api('GET', '/status', { token: adminToken });
  const guestBoard = r.json.board.find((b) => b.userId === guestId);
  assert(guestBoard.sleepStatus === 'awake', '상태창에 취침/기상 상태가 반영된다');

  ownerSocket.close();
  guestSocket.close();
  server.close();

  console.log(`\n${failures === 0 ? '모든 테스트 통과' : `${failures}개 실패`}`);
  fs.unlink(dbPath, () => {});
  fs.unlink(`${dbPath}-journal`, () => {});
  fs.unlink(`${dbPath}-wal`, () => {});
  fs.unlink(`${dbPath}-shm`, () => {});
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
