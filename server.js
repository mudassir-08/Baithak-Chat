const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');
const multer = require('multer');
const { Server } = require('socket.io');

const PORT = 3000;
const ADMIN_PASSWORD = 'gtasan';
const UPLOAD_DIR = path.join(__dirname, 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const app = express();
const server = http.createServer(app);
const io = new Server(server);

const users = new Map(); // socket.id -> name
const history = [];      // last 100 public messages (in memory)

function postMessage(msg) {
  history.push(msg);
  if (history.length > 100) history.shift();
  io.emit('message', msg);
}

function userList() {
  return [...users].map(([id, name]) => ({ id, name }));
}

// ---------- File upload ----------
const storage = multer.diskStorage({
  destination: UPLOAD_DIR,
  filename: (req, file, cb) => {
    const safe = path.basename(file.originalname).replace(/[^\w.\- ]/g, '_');
    // Private files get a random "P..." prefix so they are not listed publicly
    const isPrivate = !!req.headers['x-to'];
    const prefix = isPrivate ? 'P' + crypto.randomBytes(6).toString('hex') : String(Date.now());
    cb(null, prefix + '-' + safe);
  },
});
const upload = multer({ storage, limits: { fileSize: 500 * 1024 * 1024 } }); // 500 MB

function listFiles() {
  return fs
    .readdirSync(UPLOAD_DIR)
    .filter((id) => !id.startsWith('P')) // hide private files
    .map((id) => {
      const stat = fs.statSync(path.join(UPLOAD_DIR, id));
      return {
        id,
        name: id.slice(id.indexOf('-') + 1),
        size: stat.size,
        time: stat.mtimeMs,
      };
    })
    .sort((a, b) => b.time - a.time);
}

app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/files', (req, res) => res.json(listFiles()));

app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file' });

  const fail = (code, msg) => {
    fs.unlink(req.file.path, () => {});
    return res.status(code).json({ error: msg });
  };

  const senderId = req.headers['x-socket-id'];
  const sender = users.get(senderId);
  const toId = req.headers['x-to'] || '';

  if (!sender) return fail(401, 'Join the chat first');
  if (toId && !users.has(toId)) return fail(400, 'That user is no longer online');

  const id = req.file.filename;
  const msg = {
    type: 'file',
    name: sender,
    fromId: senderId,
    fileId: id,
    fileName: id.slice(id.indexOf('-') + 1),
    size: req.file.size,
    time: Date.now(),
  };

  if (toId) {
    msg.private = true;
    msg.toId = toId;
    io.to(toId).emit('private', msg);
    io.to(senderId).emit('private', msg);
  } else {
    postMessage(msg);
    io.emit('files', listFiles());
  }
  res.json({ ok: true });
});

app.get('/download/:id', (req, res) => {
  const id = path.basename(req.params.id);
  const filePath = path.join(UPLOAD_DIR, id);
  if (!fs.existsSync(filePath)) return res.status(404).send('File not found');
  res.download(filePath, id.slice(id.indexOf('-') + 1));
});

app.delete('/api/files/:id', (req, res) => {
  if (req.headers['x-admin-password'] !== ADMIN_PASSWORD) {
    return res.status(403).json({ error: 'Wrong password' });
  }
  const id = path.basename(req.params.id);
  const filePath = path.join(UPLOAD_DIR, id);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }
  fs.unlinkSync(filePath);
  io.emit('files', listFiles());
  postMessage({
    type: 'system',
    text: `File deleted: ${id.slice(id.indexOf('-') + 1)}`,
    time: Date.now(),
  });
  res.json({ ok: true });
});


// Handle upload errors (e.g. file too large)
app.use((err, req, res, next) => {
  console.error('UPLOAD ERROR:', err);
  res.status(400).json({ error: err.message });
});

// ---------- Chat ----------
io.on('connection', (socket) => {
  socket.emit('history', history);
  socket.emit('files', listFiles());
  socket.emit('users', userList());

  socket.on('join', (name, ack) => {
    name = String(name || '').trim().slice(0, 20) || 'Guest';

    // Make names unique: Ali, Ali (2), Ali (3)...
    const taken = new Set();
    for (const [id, n] of users) if (id !== socket.id) taken.add(n);
    let finalName = name;
    let n = 2;
    while (taken.has(finalName)) finalName = `${name} (${n++})`;

    users.set(socket.id, finalName);
    if (typeof ack === 'function') ack(finalName);
    io.emit('users', userList());
    postMessage({ type: 'system', text: `${finalName} joined`, time: Date.now() });
  });

  // Public message
  socket.on('message', (text) => {
    const name = users.get(socket.id);
    if (!name) return;
    text = String(text || '').trim().slice(0, 1000);
    if (!text) return;
    postMessage({ type: 'chat', name, fromId: socket.id, text, time: Date.now() });
  });

  // Private message: delivered only to the sender and the recipient
  socket.on('private', (data, ack) => {
    const reply = typeof ack === 'function' ? ack : () => {};
    const name = users.get(socket.id);
    if (!name) return reply({ ok: false, error: 'Join the chat first' });

    const toId = String((data && data.to) || '');
    const text = String((data && data.text) || '').trim().slice(0, 1000);
    if (!text) return reply({ ok: false, error: 'Empty message' });
    if (toId === socket.id) return reply({ ok: false, error: 'You cannot message yourself' });
    if (!users.has(toId)) return reply({ ok: false, error: 'That user is no longer online' });

    const msg = { type: 'chat', private: true, name, fromId: socket.id, toId, text, time: Date.now() };
    io.to(toId).emit('private', msg);
    socket.emit('private', msg);
    reply({ ok: true });
  });

  socket.on('disconnect', () => {
    const name = users.get(socket.id);
    if (!name) return;
    users.delete(socket.id);
    io.emit('users', userList());
    postMessage({ type: 'system', text: `${name} left`, time: Date.now() });
  });
});

// ---------- Start ----------
server.listen(PORT, '0.0.0.0', () => {
  console.log('LocalShare running. Open one of these on a connected device:');
  for (const list of Object.values(os.networkInterfaces())) {
    for (const i of list) {
      if (i.family === 'IPv4' && !i.internal) console.log(`  http://${i.address}:${PORT}`);
    }
  }
});
