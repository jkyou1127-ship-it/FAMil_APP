require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const http = require('http');

const { initSockets } = require('./sockets');
const { startCronJobs } = require('./cron');
const { startDiscoveryResponder } = require('./discovery');

const authRoutes = require('./routes/auth');
const backupRoutes = require('./routes/backup');
const userRoutes = require('./routes/users');
const roomRoutes = require('./routes/rooms');
const messageRoutes = require('./routes/messages');
const chatRoomRoutes = require('./routes/chatRooms');
const suggestionRoutes = require('./routes/suggestions');
const statusRoutes = require('./routes/status');
const sleepRoutes = require('./routes/sleep');
const alarmRoutes = require('./routes/alarms');
const scheduleRoutes = require('./routes/schedules');
const todoRoutes = require('./routes/todos');

const app = express();
const server = http.createServer(app);

app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.get('/health', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));

app.use('/auth', authRoutes);
app.use('/backup', backupRoutes);
app.use('/users', userRoutes);
app.use('/rooms', roomRoutes);
app.use('/messages', messageRoutes);
app.use('/chat-rooms', chatRoomRoutes);
app.use('/suggestions', suggestionRoutes);
app.use('/status', statusRoutes);
app.use('/sleep', sleepRoutes);
app.use('/alarms', alarmRoutes);
app.use('/schedules', scheduleRoutes);
app.use('/todos', todoRoutes);

app.use((req, res) => res.status(404).json({ error: 'Not found' }));
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: '서버 오류가 발생했습니다.' });
});

initSockets(server);
startCronJobs();

const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`FAMil APP backend listening on port ${PORT}`);
  startDiscoveryResponder(PORT);
});

module.exports = { app, server };
