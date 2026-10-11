'use strict';
const sql = require('mssql');

function config() {
  const c = {
    server: process.env.DB_SERVER || 'localhost',
    database: process.env.DB_NAME || 'EcommerceBanfield',
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    options: {
      encrypt: process.env.DB_ENCRYPT === 'true',
      trustServerCertificate: process.env.DB_TRUST_CERT !== 'false',
    },
    pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
    requestTimeout: 20000,
  };
  if (process.env.DB_PORT) c.port = parseInt(process.env.DB_PORT, 10);
  return c;
}

let poolPromise = null;
function pool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config()).connect().catch((e) => { poolPromise = null; throw e; });
  }
  return poolPromise;
}

// Los parámetros se envían siempre con input(): nunca se arma SQL concatenando datos del usuario.
function bind(request, params) {
  for (const [k, v] of Object.entries(params || {})) {
    if (v && typeof v === 'object' && 'type' in v && 'value' in v) request.input(k, v.type, v.value);
    else request.input(k, v === undefined ? null : v);
  }
  return request;
}

async function query(text, params) {
  const p = await pool();
  return bind(p.request(), params).query(text);
}

async function exec(procedure, params) {
  const p = await pool();
  return bind(p.request(), params).execute(procedure);
}

// Transacción: todo o nada.
async function tx(fn) {
  const p = await pool();
  const t = new sql.Transaction(p);
  await t.begin();
  try {
    const out = await fn({ query: (text, params) => bind(new sql.Request(t), params).query(text) });
    await t.commit();
    return out;
  } catch (e) {
    try { await t.rollback(); } catch (_) { /* ya estaba cerrada */ }
    throw e;
  }
}

module.exports = { query, exec, tx, sql };
