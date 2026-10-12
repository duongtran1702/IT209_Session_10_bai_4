const http = require('http');
const { Pool } = require('pg');

const PORT = parseInt(process.env.PORT || '8080', 10);
const DB_HOST = process.env.DB_HOST || 'db-server';
const DB_PORT = parseInt(process.env.DB_PORT || '5432', 10);
const DB_NAME = process.env.DB_NAME || 'appdb';
const DB_USER = process.env.DB_USER || 'appuser';
const DB_PASSWORD = process.env.DB_PASSWORD || 'secretpassword123';

const pool = new Pool({
  host: DB_HOST,
  port: DB_PORT,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
  connectionTimeoutMillis: 5000,
});

// Khoi tao bang du lieu khi ung dung khoi dong
async function initDb() {
  let retries = 10;
  while (retries > 0) {
    try {
      const client = await pool.connect();
      console.log(`[DB INFO] Ket noi thanh cong toi PostgreSQL tai ${DB_HOST}:${DB_PORT}/${DB_NAME}`);
      await client.query(`
        CREATE TABLE IF NOT EXISTS inventory (
          id SERIAL PRIMARY KEY,
          item_name VARCHAR(100) NOT NULL,
          quantity INT DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      `);
      client.release();
      return;
    } catch (err) {
      console.log(`[DB WAIT] Dang cho PostgreSQL khoi dong... (${err.message}). Con ${retries} lan thu.`);
      retries--;
      await new Promise((res) => setTimeout(res, 2000));
    }
  }
  console.warn('[DB WARN] Chua the ket noi Database sau cac lan thu. Se thu lai trong request tiep theo.');
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');

  // Endpoint: GET /health
  if (req.url === '/health' && req.method === 'GET') {
    try {
      const result = await pool.query('SELECT NOW() as current_time;');
      res.writeHead(200);
      return res.end(JSON.stringify({
        status: 'UP',
        service: 'Backend Web API',
        database: 'CONNECTED',
        db_host: DB_HOST,
        db_timestamp: result.rows[0].current_time,
      }, null, 2));
    } catch (err) {
      res.writeHead(503);
      return res.end(JSON.stringify({
        status: 'DOWN',
        database: 'DISCONNECTED',
        error: err.message,
      }, null, 2));
    }
  }

  // Endpoint: GET /api/items
  if (req.url === '/api/items' && req.method === 'GET') {
    try {
      const result = await pool.query('SELECT * FROM inventory ORDER BY id ASC;');
      res.writeHead(200);
      return res.end(JSON.stringify({
        success: true,
        total: result.rowCount,
        data: result.rows,
      }, null, 2));
    } catch (err) {
      res.writeHead(500);
      return res.end(JSON.stringify({
        success: false,
        error: err.message,
      }, null, 2));
    }
  }

  // Endpoint: POST /api/items
  if (req.url === '/api/items' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', async () => {
      try {
        const payload = body ? JSON.parse(body) : {};
        const itemName = payload.item_name || `Item-${Date.now()}`;
        const quantity = payload.quantity || 1;
        const result = await pool.query(
          'INSERT INTO inventory (item_name, quantity) VALUES ($1, $2) RETURNING *;',
          [itemName, quantity]
        );
        res.writeHead(201);
        return res.end(JSON.stringify({
          success: true,
          message: 'Them ban ghi thanh cong',
          item: result.rows[0],
        }, null, 2));
      } catch (err) {
        res.writeHead(500);
        return res.end(JSON.stringify({
          success: false,
          error: err.message,
        }, null, 2));
      }
    });
    return;
  }

  // Endpoint mac dinh: GET /
  if (req.url === '/' && req.method === 'GET') {
    let dbStatus = 'DISCONNECTED';
    try {
      await pool.query('SELECT 1;');
      dbStatus = 'CONNECTED';
    } catch (_) {}

    res.writeHead(200);
    return res.end(JSON.stringify({
      message: 'IT209 - Session 10: Multi-Container Docker Environment',
      student: {
        name: 'Trần Trí Dương',
        github: 'duongtran1702',
        class: 'IT209',
      },
      configuration: {
        server_port: PORT,
        db_host: DB_HOST,
        db_port: DB_PORT,
        db_name: DB_NAME,
        db_user: DB_USER,
        db_status: dbStatus,
      },
      endpoints: [
        { method: 'GET', path: '/', description: 'Thong tin tong quan dich vu' },
        { method: 'GET', path: '/health', description: 'Kiem tra trang thai suc khoe & ket noi DB' },
        { method: 'GET', path: '/api/items', description: 'Lay danh sach du lieu tu PostgreSQL' },
        { method: 'POST', path: '/api/items', description: 'Them ban ghi moi vao PostgreSQL' },
      ],
    }, null, 2));
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Endpoint not found' }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[SERVER INFO] Backend Web API dang lang nghe tai http://0.0.0.0:${PORT}`);
  initDb();
});
