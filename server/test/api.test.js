import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

process.env.DB_PATH = path.join(os.tmpdir(), `famil-test-${Date.now()}-${process.pid}.db`);
process.env.JWT_SECRET = 'test-secret';

const { createApp } = await import('../src/app.js');

const app = createApp();
const server = http.createServer(app);
await new Promise((resolve) => server.listen(0, resolve));
const base = `http://localhost:${server.address().port}`;

async function json(method, urlPath, { token, body } = {}) {
  const res = await fetch(`${base}${urlPath}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

test('첫 계정은 자동으로 관리자가 되고, 그다음 계정은 일반 사용자다', async () => {
  const admin = await json('POST', '/auth/signup', {
    body: { email: 'admin@test.com', password: 'password1', displayName: '관리자' },
  });
  assert.equal(admin.status, 201);
  assert.equal(admin.data.user.role, 'admin');

  const member = await json('POST', '/auth/signup', {
    body: { email: 'member@test.com', password: 'password1', displayName: '멤버' },
  });
  assert.equal(member.status, 201);
  assert.equal(member.data.user.role, 'member');
});

test('인증 없이 보호된 엔드포인트에 접근하면 401', async () => {
  const res = await json('GET', '/users');
  assert.equal(res.status, 401);
});

test('로그인 → 방 생성/소유자 배정(관리자) → 노크 → 승인 흐름', async () => {
  const adminLogin = await json('POST', '/auth/login', {
    body: { email: 'admin@test.com', password: 'password1' },
  });
  const memberLogin = await json('POST', '/auth/login', {
    body: { email: 'member@test.com', password: 'password1' },
  });
  const adminToken = adminLogin.data.token;
  const memberToken = memberLogin.data.token;
  const memberUid = memberLogin.data.user.uid;

  // 일반 사용자는 방을 만들 수 없다.
  const forbidden = await json('POST', '/rooms', { token: memberToken, body: { name: '실패방' } });
  assert.equal(forbidden.status, 403);

  const room = await json('POST', '/rooms', { token: adminToken, body: { name: '201호' } });
  assert.equal(room.status, 201);
  const roomId = room.data.room.id;

  const assign = await json('POST', `/rooms/${roomId}/assign-owner`, {
    token: adminToken,
    body: { uid: memberUid },
  });
  assert.equal(assign.data.room.ownerUid, memberUid);

  const knock = await json('POST', '/knocks', { token: adminToken, body: { roomId } });
  assert.equal(knock.status, 201);
  assert.equal(knock.data.knock.status, 'pending');

  const incoming = await json('GET', '/knocks/incoming', { token: memberToken });
  assert.equal(incoming.data.knocks.length, 1);

  const respond = await json('PATCH', `/knocks/${knock.data.knock.id}/respond`, {
    token: memberToken,
    body: { approve: true },
  });
  assert.equal(respond.data.knock.status, 'approved');

  const responses = await json('GET', '/knocks/responses', { token: adminToken });
  assert.equal(responses.data.knocks.length, 1);
});

test('할 일 등록/완료 처리', async () => {
  const login = await json('POST', '/auth/login', {
    body: { email: 'admin@test.com', password: 'password1' },
  });
  const token = login.data.token;

  const created = await json('POST', '/todos', { token, body: { text: '청소하기' } });
  assert.equal(created.status, 201);
  const todoId = created.data.todo.id;

  const done = await json('PATCH', `/todos/${todoId}`, { token, body: { done: true } });
  assert.equal(done.data.todo.done, true);
  assert.ok(done.data.todo.doneAt);
});

test('건의사항은 익명으로 저장되고 모두 조회 가능하다', async () => {
  const login = await json('POST', '/auth/login', {
    body: { email: 'member@test.com', password: 'password1' },
  });
  const token = login.data.token;

  const created = await json('POST', '/suggestions', { token, body: { text: '건의합니다' } });
  assert.equal(created.status, 201);

  const list = await json('GET', '/suggestions', { token });
  assert.ok(list.data.suggestions.some((s) => s.text === '건의합니다'));
  // uid 등 작성자 식별 정보가 응답에 없는지 확인.
  assert.ok(!('uid' in list.data.suggestions[0]));
});

after(() => {
  server.close();
  for (const suffix of ['', '-wal', '-shm']) {
    fs.rmSync(process.env.DB_PATH + suffix, { force: true });
  }
});
