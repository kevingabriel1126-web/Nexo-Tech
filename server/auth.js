'use strict';
const crypto = require('crypto');

function secret() {
  const s = process.env.TOKEN_SECRET;
  if (!s || s.length < 16) {
    if (process.env.NODE_ENV === 'production') throw new Error('Falta TOKEN_SECRET (mínimo 16 caracteres) en el archivo .env');
    return 'clave-solo-para-desarrollo-no-usar-en-produccion';
  }
  return s;
}

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');

// Token firmado con HMAC-SHA256 (mismo formato que un JWT HS256).
function sign(payload, ttlSeconds = 8 * 3600) {
  const h = b64({ alg: 'HS256', typ: 'JWT' });
  const p = b64({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSeconds });
  const sig = crypto.createHmac('sha256', secret()).update(h + '.' + p).digest('base64url');
  return h + '.' + p + '.' + sig;
}

function verify(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const expected = crypto.createHmac('sha256', secret()).update(parts[0] + '.' + parts[1]).digest();
  let got;
  try { got = Buffer.from(parts[2], 'base64url'); } catch (e) { return null; }
  if (got.length !== expected.length || !crypto.timingSafeEqual(got, expected)) return null;
  try {
    const p = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    if (!p.exp || p.exp < Date.now() / 1000) return null;
    return p;
  } catch (e) { return null; }
}

// Límite simple de intentos por clave (por ejemplo, por IP) para frenar la fuerza bruta en el login.
const hits = new Map();
function tooMany(key, max = 10, windowMs = 5 * 60 * 1000) {
  const now = Date.now();
  if (hits.size > 5000) for (const [k, v] of hits) if (v.reset < now) hits.delete(k);
  let h = hits.get(key);
  if (!h || h.reset < now) { h = { n: 0, reset: now + windowMs }; hits.set(key, h); }
  h.n++;
  return h.n > max;
}

// Solo para las pruebas automáticas.
const _resetLimits = () => hits.clear();

module.exports = { sign, verify, tooMany, _resetLimits };
