'use strict';
const fs = require('fs');
const path = require('path');
const http = require('http');

// Carga mínima del archivo .env (sin dependencias extra).
function loadEnv() {
  const file = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = /^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/.exec(line);
    if (!m || line.trim().startsWith('#')) continue;
    let v = m[2];
    const c = v.indexOf(' #');             // comentario al final de la línea
    if (c >= 0 && !/^["']/.test(v)) v = v.slice(0, c).trim();
    v = v.replace(/^["']|["']$/g, '');
    if (process.env[m[1]] === undefined) process.env[m[1]] = v;
  }
}
loadEnv();

const { routes, HttpError } = require('./routes');
const { verify } = require('./auth');

const PUBLIC = path.join(__dirname, '..', 'public');
const UPLOADS = path.join(__dirname, '..', 'uploads');
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
};
const MAX_BODY = 1.5 * 1024 * 1024;

function send(res, status, body, headers = {}) {
  const data = typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'same-origin',
    'Cache-Control': 'no-store',
    ...headers,
  });
  res.end(data);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) { reject(new HttpError(413, 'El pedido es demasiado grande.')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch (e) { reject(new HttpError(400, 'El cuerpo de la solicitud no es un JSON válido.')); }
    });
    req.on('error', reject);
  });
}

function sqlErrorToHttp(e) {
  if (e instanceof HttpError) return { status: e.status, message: e.message };
  const n = e.number || (e.originalError && e.originalError.info && e.originalError.info.number);
  if (n >= 50000 && n < 60000) return { status: 400, message: e.message };      // errores de negocio (THROW de los procedimientos)
  if (n === 2627 || n === 2601) return { status: 409, message: 'Ya existe un registro con esos datos.' };
  if (n === 547) return { status: 400, message: 'Hay datos que no son válidos o que están en uso.' };
  console.error('[error]', e);
  return { status: 500, message: 'Ocurrió un error en el servidor. Probá de nuevo en unos minutos.' };
}

async function handleApi(req, res, url) {
  const method = req.method;
  let match = null;
  let pathMatched = false;
  for (const r of routes) {
    const m = r.re.exec(url.pathname);
    if (!m) continue;
    pathMatched = true;
    if (r.method === method) { match = { r, m }; break; }
  }
  if (!match) return send(res, pathMatched ? 405 : 404, { error: pathMatched ? 'Método no permitido.' : 'No existe esa ruta.' });

  const { r, m } = match;
  const ctx = { params: {}, query: Object.fromEntries(url.searchParams), body: {}, user: null, ip: req.socket.remoteAddress || '' };
  r.names.forEach((n, i) => { ctx.params[n] = m[i + 1]; });

  // Autenticación y permisos: se controlan SIEMPRE acá, en el servidor.
  if (r.opts.auth) {
    const h = req.headers.authorization || '';
    const user = verify(h.startsWith('Bearer ') ? h.slice(7) : '');
    if (!user) return send(res, 401, { error: 'Tenés que iniciar sesión.' });
    if (r.opts.auth === 'emp' && user.t !== 'emp') return send(res, 403, { error: 'No tenés permiso para esto.' });
    if (r.opts.auth === 'cli' && user.t !== 'cli') return send(res, 403, { error: 'No tenés permiso para esto.' });
    if (r.opts.perms && !r.opts.perms.some((p) => (user.perms || []).includes(p)))
      return send(res, 403, { error: 'Tu rol no tiene permiso para esto.' });
    ctx.user = user;
  }
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) ctx.body = await readBody(req);
  const out = await r.handler(ctx);
  return send(res, 200, out === undefined ? { ok: true } : out);
}

function serveFile(res, root, rel) {
  const file = path.normalize(path.join(root, rel));
  if (!file.startsWith(root + path.sep) && file !== root) return send(res, 403, 'Prohibido', { 'Content-Type': 'text/plain' });
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) return send(res, 404, 'No encontrado', { 'Content-Type': 'text/plain' });
    const ext = path.extname(file).toLowerCase();
    if (!MIME[ext]) return send(res, 404, 'No encontrado', { 'Content-Type': 'text/plain' });
    res.writeHead(200, {
      'Content-Type': MIME[ext],
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': ext === '.html' ? 'no-store' : 'public, max-age=3600',
      ...(ext === '.html' ? { 'Content-Security-Policy': "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; frame-ancestors 'none'" } : {}),
    });
    fs.createReadStream(file).pipe(res);
  });
}

function createServer() {
  fs.mkdirSync(UPLOADS, { recursive: true });
  return http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname.startsWith('/api/')) return await handleApi(req, res, url);
      if (req.method !== 'GET' && req.method !== 'HEAD') return send(res, 405, 'Método no permitido', { 'Content-Type': 'text/plain' });
      if (url.pathname.startsWith('/uploads/')) return serveFile(res, UPLOADS, decodeURIComponent(url.pathname.slice('/uploads/'.length)));
      return serveFile(res, PUBLIC, url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1)));
    } catch (e) {
      const { status, message } = sqlErrorToHttp(e);
      if (!res.headersSent) send(res, status, { error: message });
    }
  });
}

if (require.main === module) {
  const port = parseInt(process.env.PORT || '3000', 10);
  createServer().listen(port, () => console.log(`Nexo Tech en http://localhost:${port}`));
}
module.exports = { createServer };
