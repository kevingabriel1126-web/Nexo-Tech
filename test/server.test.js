'use strict';
// Pruebas del servidor SIN base de datos real: se reemplaza el módulo "mssql" por uno falso
// que registra las consultas y devuelve datos de ejemplo. Verifican permisos, validaciones,
// manejo de errores y que los datos del usuario viajen siempre como parámetros.
const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');

process.env.TOKEN_SECRET = 'secreto-de-prueba-bastante-largo';

const state = { handlers: [], log: [] };
const rs = (rows) => ({ recordset: rows, rowsAffected: [rows.length] });
function answer(kind, name, params) {
  for (const h of state.handlers) {
    if ((h.kind && h.kind !== kind)) continue;
    const ok = h.match instanceof RegExp ? h.match.test(name) : name.includes(h.match);
    if (!ok) continue;
    const out = typeof h.reply === 'function' ? h.reply(params, name) : h.reply;
    if (out instanceof Error) throw out;
    return rs(out);
  }
  return rs([]);
}
class Request {
  constructor() { this.params = {}; }
  input(n, a, b) { this.params[n] = b === undefined ? a : b; return this; }
  async query(text) { state.log.push({ kind: 'query', text, params: { ...this.params } }); return answer('query', text, this.params); }
  async execute(proc) { state.log.push({ kind: 'exec', proc, params: { ...this.params } }); return answer('exec', proc, this.params); }
}
const fakeSql = {
  ConnectionPool: class { connect() { return Promise.resolve({ request: () => new Request() }); } },
  Request,
  Transaction: class { begin() { return Promise.resolve(); } commit() { return Promise.resolve(); } rollback() { return Promise.resolve(); } },
};
const origLoad = Module._load;
Module._load = function (req) { return req === 'mssql' ? fakeSql : origLoad.apply(this, arguments); };

const { createServer } = require('../server/index');
const { sign, _resetLimits } = require('../server/auth');

let server, base;
test.before(async () => {
  server = createServer();
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
test.after(() => server.close());
test.beforeEach(() => { state.handlers = []; state.log = []; _resetLimits(); });

const call = async (method, path, { body, token } = {}) => {
  const r = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null; try { data = await r.json(); } catch (e) { /* sin cuerpo JSON */ }
  return { status: r.status, data };
};
const emp = (role, perms) => sign({ t: 'emp', id: 9, user: role, name: role, role, perms });
const OWNER = ['ventas', 'pedidos', 'facturacion', 'ganancias', 'arrepentimientos', 'newsletter', 'stock', 'precios', 'altabaja', 'empleados'];

test('catálogo público: arma los productos con versiones y colores, sin costos', async () => {
  state.handlers.push(
    { match: /FROM dbo\.Productos p/, reply: [{ id: 1, name: 'Notebook', desc: null, cat: 'Computación', kind: 'notebook', brand: 'Vektra', year: '2026', net: 100, iva: 21, disc: 0, stock: 5, emoji: '💻', img: null, activo: true }] },
    { match: /ProductoVersiones/, reply: [{ id: 1, n: '256 GB SSD' }, { id: 1, n: '512 GB SSD' }] },
    { match: /ProductoColores/, reply: [{ id: 1, n: 'Gris' }] });
  const r = await call('GET', '/api/productos');
  assert.equal(r.status, 200);
  assert.deepEqual(r.data[0].sizes, ['256 GB SSD', '512 GB SSD']);
  assert.deepEqual(r.data[0].colors, ['Gris']);
  assert.equal(r.data[0].cost, undefined);
  assert.ok(!/CostoNeto/.test(state.log[0].text), 'la consulta pública no pide el costo');
});

test('rutas de empleados: 401 sin sesión, 403 sin permiso o con sesión de cliente', async () => {
  assert.equal((await call('GET', '/api/admin/pedidos')).status, 401);
  assert.equal((await call('GET', '/api/admin/pedidos', { token: 'basura.basura.basura' })).status, 401);
  const cajero = emp('cajero', ['ventas', 'pedidos']);
  assert.equal((await call('PATCH', '/api/admin/productos/1/stock', { token: cajero, body: { cantidad: 5 } })).status, 403);
  assert.equal((await call('GET', '/api/admin/ganancias', { token: cajero })).status, 403);
  const cliente = sign({ t: 'cli', id: 1, name: 'Ana', email: 'a@b.com' });
  assert.equal((await call('GET', '/api/admin/pedidos', { token: cliente })).status, 403);
});

test('solo el permiso "ganancias" permite ver ganancias y costos', async () => {
  const gerente = emp('gerente', OWNER.filter((p) => p !== 'ganancias'));
  assert.equal((await call('GET', '/api/admin/ganancias', { token: gerente })).status, 403);
  state.handlers.push({ match: /Productos p/, reply: [] });
  await call('GET', '/api/admin/productos', { token: gerente });
  assert.ok(!/CostoNeto/.test(state.log[0].text), 'el gerente no recibe costos');
  state.log = [];
  await call('GET', '/api/admin/productos', { token: emp('dueno', OWNER) });
  assert.ok(/CostoNeto/.test(state.log[0].text), 'el dueño sí recibe costos');
});

test('el costo solo se modifica con el permiso de ganancias', async () => {
  state.handlers.push({ kind: 'exec', match: 'usp_ModificarPrecio', reply: [{ IdProducto: 1 }] });
  const admin = emp('administrativo', ['stock', 'precios', 'ventas']);
  await call('PATCH', '/api/admin/productos/1/precio', { token: admin, body: { neto: 100, iva: 21, descuento: 0, costo: 1 } });
  assert.equal(state.log[0].params.CostoNeto, null);
  state.log = [];
  await call('PATCH', '/api/admin/productos/1/precio', { token: emp('dueno', OWNER), body: { neto: 100, iva: 21, descuento: 0, costo: 55 } });
  assert.equal(state.log[0].params.CostoNeto, 55);
});

test('login: empleado, cliente, error y límite de intentos', async () => {
  state.handlers.push(
    { kind: 'exec', match: 'usp_LoginEmpleado', reply: (p) => p.Usuario === 'gerente' && p.Clave === 'ok' ? [{ IdEmpleado: 2, Usuario: 'gerente', NombreCompleto: 'Laura', Rol: 'gerente' }] : [] },
    { kind: 'query', match: /RolPermisos/, reply: [{ p: 'ventas' }, { p: 'stock' }] },
    { kind: 'exec', match: 'usp_LoginCliente', reply: (p) => p.Email === 'ana@x.com' && p.Clave === 'secreta1' ? [{ IdCliente: 7, Nombre: 'Ana', Email: 'ana@x.com' }] : [] });
  let r = await call('POST', '/api/login', { body: { usuario: 'gerente', clave: 'ok' } });
  assert.equal(r.status, 200); assert.equal(r.data.tipo, 'empleado'); assert.deepEqual(r.data.user.perms, ['ventas', 'stock']); assert.ok(r.data.token);
  r = await call('POST', '/api/login', { body: { usuario: 'ANA@x.com', clave: 'secreta1' } });
  assert.equal(r.data.tipo, 'cliente');
  r = await call('POST', '/api/login', { body: { usuario: 'gerente', clave: 'mala' } });
  assert.equal(r.status, 401);
  // el token del login sirve para /api/yo
  const yo = await call('GET', '/api/yo', { token: (await call('POST', '/api/login', { body: { usuario: 'gerente', clave: 'ok' } })).data.token });
  assert.equal(yo.data.user.role, 'gerente');
});

test('login: bloquea la fuerza bruta (429)', async () => {
  let last;
  for (let i = 0; i < 14; i++) last = await call('POST', '/api/login', { body: { usuario: 'x' + i, clave: 'y' } });
  assert.equal(last.status, 429);
});

test('inyección SQL: lo que escribe el usuario viaja como parámetro, nunca dentro del texto SQL', async () => {
  const evil = "x' OR 1=1; DROP TABLE Productos;--";
  await call('POST', '/api/login', { body: { usuario: evil, clave: 'a' } });
  assert.ok(state.log.length > 0);
  for (const l of state.log) assert.ok(!(l.text || '').includes('DROP TABLE'));
  assert.ok(state.log.some((l) => Object.values(l.params).includes(evil.toLowerCase()) || Object.values(l.params).includes(evil)));
});

test('pedido sin cuenta: valida los datos y llama al procedimiento con parámetros', async () => {
  assert.equal((await call('POST', '/api/pedidos', { body: { nombre: 'Ana', email: 'mal', retiro: true, items: [{ idProducto: 1, cantidad: 1 }] } })).status, 400);
  state.handlers.push({ match: /FROM dbo\.Versiones/, reply: [{ id: 1, n: '128 GB' }] }, { match: /FROM dbo\.Colores/, reply: [{ id: 1, n: 'Negro' }] });
  assert.equal((await call('POST', '/api/pedidos', { body: { nombre: 'Ana', email: 'a@b.com', retiro: true, items: [] } })).status, 400);
  assert.equal((await call('POST', '/api/pedidos', { body: { nombre: 'Ana', email: 'a@b.com', retiro: false, items: [{ idProducto: 1, cantidad: 1 }] } })).status, 400, 'falta la dirección');
  assert.equal((await call('POST', '/api/pedidos', { body: { nombre: 'Ana', email: 'a@b.com', retiro: true, items: [{ idProducto: 1, cantidad: 1, version: '999 TB' }] } })).status, 400);
  state.log = [];
  state.handlers.push(
    { kind: 'exec', match: 'usp_RegistrarPedido', reply: [{ IdPedido: 1000, Total: 500 }] },
    { kind: 'query', match: /FROM dbo\.Pedidos p JOIN/, reply: [{ id: 1000, date: '2026-10-10T10:00:00', estado: 'pendiente', retiro: true, addr: null, sub: 500, dsc: 0, envio: 0, net: 413, iva: 87, total: 500, cliente: 'Ana', email: 'a@b.com' }] },
    { kind: 'query', match: /FROM dbo\.DetallePedido/, reply: [{ oid: 1000, id: 1, name: 'Celular', qty: 1, net: 413, iva: 21, size: '128 GB', color: 'Negro' }] });
  const r = await call('POST', '/api/pedidos', { body: { nombre: 'Ana', email: 'A@B.com', retiro: true, items: [{ idProducto: 1, cantidad: 1, version: '128 GB', color: 'Negro' }] } });
  assert.equal(r.status, 200);
  assert.equal(r.data.order.id, 1000);
  assert.equal(r.data.order.items[0].size, '128 GB');
  const call1 = state.log.find((l) => l.proc === 'dbo.usp_RegistrarPedido');
  assert.equal(call1.params.Email, 'a@b.com');
  assert.deepEqual(JSON.parse(call1.params.ItemsJson), [{ idProducto: 1, idVersion: 1, idColor: 1, cantidad: 1 }]);
});

test('errores de negocio de SQL Server (THROW 5xxxx) llegan como 400 con su mensaje', async () => {
  const err = new Error('No hay stock suficiente para completar el pedido.'); err.number = 50008;
  state.handlers.push({ match: /FROM dbo\.Versiones/, reply: [] }, { match: /FROM dbo\.Colores/, reply: [] }, { kind: 'exec', match: 'usp_RegistrarPedido', reply: err });
  const r = await call('POST', '/api/pedidos', { body: { nombre: 'Ana', email: 'a@b.com', retiro: true, items: [{ idProducto: 1, cantidad: 3 }] } });
  assert.equal(r.status, 400);
  assert.match(r.data.error, /stock/);
});

test('un error inesperado devuelve 500 sin mostrar detalles internos', async () => {
  const err = new Error('Login failed for user sa at 10.0.0.5'); err.number = 18456;
  state.handlers.push({ kind: 'query', match: /Productos/, reply: err });
  const r = await call('GET', '/api/productos');
  assert.equal(r.status, 500);
  assert.ok(!/10\.0\.0\.5/.test(JSON.stringify(r.data)));
});

test('empleados: se pasa el rol de quien pide para que el procedimiento controle al dueño', async () => {
  state.handlers.push({ kind: 'exec', match: 'usp_CrearEmpleado', reply: [{ IdEmpleado: 9 }] });
  const gerente = emp('gerente', ['empleados']);
  await call('POST', '/api/admin/empleados', { token: gerente, body: { usuario: 'nuevo', nombre: 'Nuevo', rol: 'dueno', clave: 'abcd' } });
  assert.equal(state.log[0].params.RolSolicitante, 'gerente');
  assert.equal((await call('POST', '/api/admin/empleados', { token: gerente, body: { usuario: 'n', nombre: 'N', rol: 'cajero', clave: '12' } })).status, 400, 'contraseña corta');
});

test('estados de pedido: solo valores válidos', async () => {
  state.handlers.push({ kind: 'exec', match: 'usp_CambiarEstadoPedido', reply: [] });
  const t = emp('cajero', ['ventas', 'pedidos']);
  assert.equal((await call('PATCH', '/api/admin/pedidos/1000/estado', { token: t, body: { estado: 'regalado' } })).status, 400);
  assert.equal((await call('PATCH', '/api/admin/pedidos/1000/estado', { token: t, body: { estado: 'enviado' } })).status, 200);
});

test('archivos estáticos: no se puede salir de la carpeta pública', async () => {
  for (const p of ['/../server/auth.js', '/..%2Fserver%2Fauth.js', '/%2e%2e/.env', '/uploads/../server/db.js']) {
    const r = await fetch(base + p);
    assert.ok([403, 404].includes(r.status), p + ' => ' + r.status);
  }
});
