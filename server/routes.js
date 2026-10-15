'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { query, exec, tx } = require('./db');
const { sign, tooMany } = require('./auth');

const UPLOADS = path.join(__dirname, '..', 'uploads');
const ESTADOS_PEDIDO = ['pendiente', 'pagado', 'enviado', 'entregado', 'cancelado'];
const ESTADOS_ARREP = ['recibida', 'en proceso', 'resuelta'];

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const bad = (m) => new HttpError(400, m);

/* ---------- validaciones ---------- */
const isEmail = (e) => typeof e === 'string' && e.length <= 150 && /^\S+@\S+\.\S+$/.test(e.trim());
function str(v, max, name, req = true) {
  if (v === undefined || v === null || v === '') { if (req) throw bad(`Falta ${name}.`); return null; }
  if (typeof v !== 'string') throw bad(`${name} no es válido.`);
  const t = v.trim();
  if (!t) { if (req) throw bad(`Falta ${name}.`); return null; }
  if (t.length > max) throw bad(`${name} es demasiado largo (máximo ${max} caracteres).`);
  return t;
}
function num(v, name, min = 0, max = 1e9) {
  const n = typeof v === 'number' ? v : parseFloat(v);
  if (!Number.isFinite(n) || n < min || n > max) throw bad(`${name} no es válido.`);
  return n;
}
function int(v, name, min = 0, max = 1e9) {
  const n = num(v, name, min, max);
  if (!Number.isInteger(n)) throw bad(`${name} tiene que ser un número entero.`);
  return n;
}
const list = (v, max = 30) => (Array.isArray(v) ? v : [])
  .map((x) => String(x).trim()).filter(Boolean).slice(0, max)
  .filter((x, i, a) => a.indexOf(x) === i);

/* ---------- lectura de datos ---------- */
async function loadProducts({ all = false, withCost = false } = {}) {
  const r = await query(
    `SELECT p.IdProducto AS id, p.Nombre AS name, p.Descripcion AS [desc], c.Nombre AS cat, t.Codigo AS kind,
            p.Marca AS brand, RTRIM(p.Anio) AS year, p.PrecioNeto AS net,
            p.IvaPorcentaje AS iva, p.DescuentoPorcentaje AS disc, p.Stock AS stock, p.Emoji AS emoji,
            p.ImagenUrl AS img, p.Activo AS activo${withCost ? ', p.CostoNeto AS cost' : ''}
     FROM dbo.Productos p
     JOIN dbo.Categorias c ON c.IdCategoria = p.IdCategoria
     LEFT JOIN dbo.TiposProducto t ON t.IdTipo = p.IdTipo
     ${all ? '' : 'WHERE p.Activo = 1'}
     ORDER BY p.IdProducto`);
  const tl = await query(`SELECT pt.IdProducto AS id, t.Nombre AS n FROM dbo.ProductoVersiones pt
                          JOIN dbo.Versiones t ON t.IdVersion = pt.IdVersion ORDER BY t.Orden`);
  const co = await query(`SELECT pc.IdProducto AS id, c.Nombre AS n FROM dbo.ProductoColores pc
                          JOIN dbo.Colores c ON c.IdColor = pc.IdColor ORDER BY c.Nombre`);
  const group = (rows) => rows.reduce((m, x) => { (m[x.id] = m[x.id] || []).push(x.n); return m; }, {});
  const sizes = group(tl.recordset), colors = group(co.recordset);
  return r.recordset.map((p) => ({
    ...p,
    desc: p.desc || '', kind: p.kind || '', brand: p.brand || '', year: p.year || '',
    emoji: p.emoji || '📦', img: p.img || '',
    sizes: sizes[p.id] || [], colors: colors[p.id] || [],
  }));
}

// Pedidos con sus ítems. `where` usa los alias p (Pedidos) y c (Clientes). Nunca incluye costos.
async function buildOrders(where, params) {
  const o = await query(
    `SELECT p.IdPedido AS id, CONVERT(VARCHAR(19), p.Fecha, 126) AS date, p.Estado AS estado, p.Retiro AS retiro,
            p.DireccionEntrega AS addr, p.DireccionCliente AS dir, p.Pais AS pais, p.Ciudad AS ciudad, p.CodigoPostal AS cp,
            p.Dni AS dni, p.PagoMarca AS pmarca, p.PagoUltimos4 AS pult,
            p.Subtotal AS sub, p.Descuento AS dsc, p.Envio AS envio,
            p.Neto AS net, p.Iva AS iva, p.Total AS total, c.Nombre AS cliente, c.Email AS email
     FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente = p.IdCliente
     ${where} ORDER BY p.Fecha, p.IdPedido`, params);
  const d = await query(
    `SELECT d.IdPedido AS oid, d.IdProducto AS id, pr.Nombre AS name, d.Cantidad AS qty, d.PrecioNetoUnitario AS net,
            d.IvaPorcentaje AS iva, ve.Nombre AS size, co.Nombre AS color
     FROM dbo.DetallePedido d
     JOIN dbo.Pedidos p ON p.IdPedido = d.IdPedido
     JOIN dbo.Clientes c ON c.IdCliente = p.IdCliente
     JOIN dbo.Productos pr ON pr.IdProducto = d.IdProducto
     LEFT JOIN dbo.Versiones ve ON ve.IdVersion = d.IdVersion
     LEFT JOIN dbo.Colores co ON co.IdColor = d.IdColor
     ${where} ORDER BY d.IdDetalle`, params);
  const items = {};
  for (const r of d.recordset) {
    (items[r.oid] = items[r.oid] || []).push({
      id: r.id, name: r.name, qty: r.qty, net: r.net, iva: r.iva, size: r.size || '', color: r.color || '',
      pers: '',
    });
  }
  return o.recordset.map(({ pmarca, pult, ...x }) => ({
    ...x,
    // Para retiro en sucursal se muestra eso; para envío, la dirección completa.
    addr: x.retiro ? 'Retiro en sucursal'
      : [x.dir || x.addr, x.ciudad && `${x.ciudad}${x.cp ? ` (${x.cp})` : ''}`, x.pais].filter(Boolean).join(', '),
    dni: x.dni || '', pais: x.pais || '', ciudad: x.ciudad || '', cp: x.cp || '', dir: x.dir || '',
    // Del pago solo se guarda la marca y los últimos 4 dígitos (nunca el número completo ni el CVC).
    pago: pult ? { marca: pmarca, ultimos4: pult, simulado: true } : null,
    items: items[x.id] || [],
  }));
}

async function permsOf(role) {
  const r = await query(`SELECT rp.Permiso AS p FROM dbo.RolPermisos rp JOIN dbo.Roles r ON r.IdRol = rp.IdRol WHERE r.Nombre = @rol`, { rol: role });
  return r.recordset.map((x) => x.p);
}

/* ---------- imágenes de productos ---------- */
function saveImage(dataUrl) {
  const m = /^data:image\/(png|jpeg|webp|gif);base64,([A-Za-z0-9+/=]+)$/.exec(dataUrl || '');
  if (!m) throw bad('La imagen tiene que ser PNG, JPG, WEBP o GIF.');
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length > 300 * 1024) throw bad('La imagen supera los 300 KB.');
  fs.mkdirSync(UPLOADS, { recursive: true });
  const name = crypto.randomBytes(12).toString('hex') + '.' + (m[1] === 'jpeg' ? 'jpg' : m[1]);
  fs.writeFileSync(path.join(UPLOADS, name), buf);
  return '/uploads/' + name;
}

/* ---------- alta y edición de productos ---------- */
async function saveProduct(user, id, b) {
  const canCost = user.perms.includes('ganancias');
  const f = {
    nombre: str(b.nombre, 150, 'el nombre'),
    descr: str(b.desc, 500, 'la descripción', false),
    cat: str(b.cat, 50, 'la categoría') ,
    kind: str(b.kind, 20, 'el tipo', false),
    brand: str(b.brand, 30, 'la marca', false),
    year: str(b.year, 4, 'el año de lanzamiento', false),
    emoji: str(b.emoji, 8, 'el ícono', false),
    neto: num(b.neto, 'el precio neto', 0, 1e8),
    iva: num(b.iva, 'el IVA', 0, 100),
    disc: num(b.disc ?? 0, 'el descuento', 0, 100),
    stock: int(b.stock ?? 0, 'el stock', 0, 1e6),
  };
  if (f.year && !/^\d{4}$/.test(f.year)) throw bad('El año de lanzamiento tiene que ser un año (por ejemplo 2026).');
  const costo = canCost && b.costo !== undefined && b.costo !== null ? num(b.costo, 'el costo', 0, 1e8) : null;
  const sizes = list(b.sizes), colors = list(b.colors);
  for (const s of sizes) if (s.length > 30) throw bad('Una versión es demasiado larga (máximo 30 caracteres).');
  for (const c of colors) if (c.length > 30) throw bad('Un color es demasiado largo.');
  const imgUrl = b.imagen ? saveImage(b.imagen) : null;

  return tx(async (t) => {
    let idCat = (await t.query(`SELECT IdCategoria FROM dbo.Categorias WHERE Nombre = @n`, { n: f.cat })).recordset[0];
    idCat = idCat ? idCat.IdCategoria
      : (await t.query(`INSERT dbo.Categorias (Nombre) OUTPUT INSERTED.IdCategoria VALUES (@n)`, { n: f.cat })).recordset[0].IdCategoria;
    const tipo = f.kind
      ? (await t.query(`SELECT IdTipo FROM dbo.TiposProducto WHERE Codigo = @c`, { c: f.kind })).recordset[0]
      : null;
    if (f.kind && !tipo) throw bad('El tipo de producto no existe.');
    const p = {
      nombre: f.nombre, descr: f.descr, cat: idCat, tipo: tipo ? tipo.IdTipo : null, marca: f.brand,
      anio: f.year, neto: f.neto, iva: f.iva, disc: f.disc, stock: f.stock, emoji: f.emoji || '📦',
    };
    let pid = id;
    if (!id) {
      pid = (await t.query(
        `INSERT dbo.Productos (Nombre, Descripcion, IdCategoria, IdTipo, Marca, Anio, PrecioNeto, CostoNeto,
                               IvaPorcentaje, DescuentoPorcentaje, Stock, Emoji, ImagenUrl)
         OUTPUT INSERTED.IdProducto
         VALUES (@nombre, @descr, @cat, @tipo, @marca, @anio, @neto, @costo, @iva, @disc, @stock, @emoji, @img)`,
        { ...p, costo: costo ?? 0, img: imgUrl })).recordset[0].IdProducto;
    } else {
      const r = await t.query(
        `UPDATE dbo.Productos SET Nombre = @nombre, Descripcion = @descr, IdCategoria = @cat, IdTipo = @tipo,
                Marca = @marca, Anio = @anio, PrecioNeto = @neto, IvaPorcentaje = @iva,
                DescuentoPorcentaje = @disc, Stock = @stock, Emoji = @emoji
                ${costo !== null ? ', CostoNeto = @costo' : ''}
                ${imgUrl ? ', ImagenUrl = @img' : ''}
         WHERE IdProducto = @id`,
        { ...p, id, costo, img: imgUrl });
      if (!r.rowsAffected || r.rowsAffected[0] === 0) throw new HttpError(404, 'El producto no existe.');
    }
    await t.query(`DELETE FROM dbo.ProductoVersiones WHERE IdProducto = @id`, { id: pid });
    for (const s of sizes) {
      let row = (await t.query(`SELECT IdVersion FROM dbo.Versiones WHERE Nombre = @n`, { n: s })).recordset[0];
      if (!row) row = (await t.query(
        `INSERT dbo.Versiones (Nombre, Orden) OUTPUT INSERTED.IdVersion
         VALUES (@n, (SELECT ISNULL(MAX(Orden), 0) + 1 FROM dbo.Versiones))`, { n: s })).recordset[0];
      await t.query(`INSERT dbo.ProductoVersiones (IdProducto, IdVersion) VALUES (@id, @t)`, { id: pid, t: row.IdVersion });
    }
    await t.query(`DELETE FROM dbo.ProductoColores WHERE IdProducto = @id`, { id: pid });
    for (const c of colors) {
      let row = (await t.query(`SELECT IdColor FROM dbo.Colores WHERE Nombre = @n`, { n: c })).recordset[0];
      if (!row) row = (await t.query(`INSERT dbo.Colores (Nombre) OUTPUT INSERTED.IdColor VALUES (@n)`, { n: c })).recordset[0];
      await t.query(`INSERT dbo.ProductoColores (IdProducto, IdColor) VALUES (@id, @c)`, { id: pid, c: row.IdColor });
    }
    return pid;
  });
}

/* ---------- ganancias (solo con permiso 'ganancias') ---------- */
const PERIODOS = {
  dia:    { vista: 'vw_GananciaDiaria',   col: 'CONVERT(VARCHAR(10), Periodo, 23)',      orden: 'Periodo' },
  semana: { vista: 'vw_GananciaSemanal',  col: 'CONVERT(VARCHAR(10), InicioSemana, 23)', orden: 'InicioSemana' },
  mes:    { vista: 'vw_GananciaMensual',  col: 'CONVERT(VARCHAR(10), Mes, 23)',          orden: 'Mes' },
  anio:   { vista: 'vw_GananciaAnual',    col: 'CAST(Anio AS VARCHAR(4))',               orden: 'Anio' },
};

/* ---------- definición de rutas ---------- */
const routes = [];
function route(method, pattern, opts, handler) {
  const names = [];
  const re = new RegExp('^' + pattern.replace(/:([a-z]+)/g, (_, n) => { names.push(n); return '(\\d+)'; }) + '$');
  routes.push({ method, re, names, opts, handler });
}
const ANY_ADMIN_PROD = ['stock', 'precios', 'altabaja'];

/* ----- públicas ----- */
route('GET', '/api/productos', {}, async () => loadProducts());

route('POST', '/api/login', {}, async (ctx) => {
  if (tooMany('login:' + ctx.ip)) throw new HttpError(429, 'Demasiados intentos. Probá de nuevo en unos minutos.');
  const usuario = str(ctx.body.usuario, 150, 'el usuario o email');
  const clave = str(ctx.body.clave, 100, 'la contraseña');
  if (usuario.length <= 30) {
    const emp = await exec('dbo.usp_LoginEmpleado', { Usuario: usuario, Clave: clave });
    if (emp.recordset.length) {
      const e = emp.recordset[0];
      const user = { id: e.IdEmpleado, user: e.Usuario, name: e.NombreCompleto, role: e.Rol, perms: await permsOf(e.Rol) };
      return { tipo: 'empleado', user, token: sign({ t: 'emp', ...user }) };
    }
  }
  const cli = await exec('dbo.usp_LoginCliente', { Email: usuario.toLowerCase(), Clave: clave });
  if (cli.recordset.length) {
    const c = cli.recordset[0];
    const user = { id: c.IdCliente, name: c.Nombre, email: c.Email };
    return { tipo: 'cliente', user, token: sign({ t: 'cli', ...user }) };
  }
  throw new HttpError(401, 'Email, usuario o contraseña incorrectos.');
});

route('POST', '/api/cuentas', {}, async (ctx) => {
  if (tooMany('cuentas:' + ctx.ip, 10, 60 * 60 * 1000)) throw new HttpError(429, 'Demasiados intentos. Probá más tarde.');
  const nombre = str(ctx.body.nombre, 100, 'el nombre');
  if (!isEmail(ctx.body.email)) throw bad('Ingresá un email válido.');
  const clave = str(ctx.body.clave, 100, 'la contraseña');
  if (clave.length < 6) throw bad('La contraseña debe tener al menos 6 caracteres.');
  const r = await exec('dbo.usp_RegistrarCuenta', { Nombre: nombre, Email: ctx.body.email.trim().toLowerCase(), Clave: clave });
  const c = r.recordset[0];
  const user = { id: c.IdCliente, name: c.Nombre, email: c.Email };
  return { tipo: 'cliente', user, token: sign({ t: 'cli', ...user }) };
});

route('GET', '/api/yo', { auth: 'any' }, async (ctx) => {
  const u = ctx.user;
  if (u.t === 'emp') return { tipo: 'empleado', user: { id: u.id, user: u.user, name: u.name, role: u.role, perms: u.perms } };
  return { tipo: 'cliente', user: { id: u.id, name: u.name, email: u.email } };
});

route('GET', '/api/mis-pedidos', { auth: 'cli' }, async (ctx) =>
  (await buildOrders('WHERE c.IdCliente = @id', { id: ctx.user.id })).reverse());

// Comprar NO requiere cuenta: este endpoint es público.
// PAGO SIMULADO: el servidor NO procesa tarjetas. Nunca recibe el número ni el CVC: solo la marca y los últimos 4 dígitos.
// Para cobrar de verdad hay que integrar una pasarela de pago (Mercado Pago, MODO, etc.) que devuelva la aprobación al servidor.
const MARCAS = ['Visa', 'Mastercard', 'American Express', 'Otra'];
const CAMPOS_TARJETA = ['numero', 'numeroTarjeta', 'tarjeta', 'cvc', 'cvv', 'vencimiento', 'venc'];
route('POST', '/api/pedidos', {}, async (ctx) => {
  const b = ctx.body;
  if (CAMPOS_TARJETA.some((k) => k in b || (b.pago && typeof b.pago === 'object' && k in b.pago)))
    throw bad('Por seguridad no se aceptan datos de la tarjeta: solo la marca y los últimos 4 dígitos.');
  const nombre = str(b.nombre, 100, 'el nombre completo');
  if (!/\S+\s+\S+/.test(nombre)) throw bad('Ingresá tu nombre completo (nombre y apellido).');
  if (!isEmail(b.email)) throw bad('Ingresá un email válido.');
  const dni = String(b.dni == null ? '' : b.dni);
  if (!/^\d{7,8}$/.test(dni)) throw bad('El DNI tiene que tener 7 u 8 números.');
  const pais = str(b.pais, 60, 'el país');
  const ciudad = str(b.ciudad, 80, 'la ciudad');
  const codigoPostal = str(b.codigoPostal, 10, 'el código postal');
  if (!/^[A-Za-z0-9 -]{3,10}$/.test(codigoPostal)) throw bad('El código postal no es válido.');
  const direccion = str(b.direccion, 200, 'la dirección');
  const retiro = !!b.retiro;
  const pago = b.pago;
  if (!pago || !MARCAS.includes(pago.marca) || !/^\d{4}$/.test(String(pago.ultimos4)))
    throw bad('Falta el pago: marca y últimos 4 dígitos de la tarjeta.');
  if (!Array.isArray(b.items) || !b.items.length || b.items.length > 50) throw bad('El pedido no tiene productos.');
  const [tl, co] = await Promise.all([
    query('SELECT IdVersion AS id, Nombre AS n FROM dbo.Versiones'),
    query('SELECT IdColor AS id, Nombre AS n FROM dbo.Colores'),
  ]);
  const tm = new Map(tl.recordset.map((x) => [x.n, x.id]));
  const cm = new Map(co.recordset.map((x) => [x.n, x.id]));
  const items = b.items.map((i) => {
    if (i.version && !tm.has(String(i.version))) throw bad('Versión inválida.');
    if (i.color && !cm.has(String(i.color))) throw bad('Color inválido.');
    return {
      idProducto: int(i.idProducto, 'el producto', 1),
      idVersion: i.version ? tm.get(String(i.version)) : null,
      idColor: i.color ? cm.get(String(i.color)) : null,
      cantidad: int(i.cantidad, 'la cantidad', 1, 100),
    };
  });
  const r = await exec('dbo.usp_RegistrarPedido', {
    Nombre: nombre, Email: b.email.trim().toLowerCase(), Retiro: retiro, Direccion: direccion,
    Pais: pais, Ciudad: ciudad, CodigoPostal: codigoPostal.toUpperCase(), Dni: dni,
    PagoMarca: pago.marca, PagoUltimos4: String(pago.ultimos4),
    ItemsJson: JSON.stringify(items),
  });
  const id = r.recordset[0].IdPedido;
  const [order] = await buildOrders('WHERE p.IdPedido = @id', { id });
  return { order };
});

route('POST', '/api/newsletter', {}, async (ctx) => {
  if (!isEmail(ctx.body.email)) throw bad('Ingresá un email válido.');
  await exec('dbo.usp_Suscribir', { Email: ctx.body.email.trim().toLowerCase() });
  return { ok: true };
});

route('POST', '/api/arrepentimientos', {}, async (ctx) => {
  const b = ctx.body;
  if (!isEmail(b.email)) throw bad('Ingresá un email válido.');
  const numero = str(b.numeroCompra, 30, 'el número de compra');
  const monto = b.monto === '' || b.monto == null ? null : num(b.monto, 'el monto', 0, 1e9);
  await exec('dbo.usp_RegistrarArrepentimiento', {
    Nombre: str(b.nombre, 100, 'el nombre', false), Email: b.email.trim().toLowerCase(), Monto: monto, NumeroCompra: numero,
  });
  return { ok: true };
});

/* ----- empleados ----- */
route('GET', '/api/admin/productos', { auth: 'emp', perms: ANY_ADMIN_PROD }, async (ctx) =>
  loadProducts({ all: true, withCost: ctx.user.perms.includes('ganancias') }));

route('POST', '/api/admin/productos', { auth: 'emp', perms: ['altabaja'] }, async (ctx) =>
  ({ id: await saveProduct(ctx.user, 0, ctx.body) }));

route('PUT', '/api/admin/productos/:id', { auth: 'emp', perms: ['altabaja'] }, async (ctx) =>
  ({ id: await saveProduct(ctx.user, parseInt(ctx.params.id, 10), ctx.body) }));

route('PATCH', '/api/admin/productos/:id/stock', { auth: 'emp', perms: ['stock'] }, async (ctx) => {
  const r = await exec('dbo.usp_AgregarStock', { IdProducto: parseInt(ctx.params.id, 10), Cantidad: int(ctx.body.cantidad, 'la cantidad', 1, 1e6) });
  return r.recordset[0];
});

route('PATCH', '/api/admin/productos/:id/precio', { auth: 'emp', perms: ['precios'] }, async (ctx) => {
  const costo = ctx.user.perms.includes('ganancias') && ctx.body.costo !== undefined && ctx.body.costo !== null
    ? num(ctx.body.costo, 'el costo', 0, 1e8) : null; // solo el dueño toca el costo
  const r = await exec('dbo.usp_ModificarPrecio', {
    IdProducto: parseInt(ctx.params.id, 10),
    PrecioNeto: num(ctx.body.neto, 'el precio neto', 0, 1e8),
    Iva: num(ctx.body.iva, 'el IVA', 0, 100),
    Descuento: num(ctx.body.descuento ?? 0, 'el descuento', 0, 100),
    CostoNeto: costo,
  });
  return r.recordset[0];
});

route('PATCH', '/api/admin/productos/:id/activo', { auth: 'emp', perms: ['altabaja'] }, async (ctx) => {
  const r = await exec('dbo.usp_CambiarActivoProducto', { IdProducto: parseInt(ctx.params.id, 10), Activo: !!ctx.body.activo });
  return r.recordset[0];
});

route('GET', '/api/admin/pedidos', { auth: 'emp', perms: ['pedidos', 'ventas', 'facturacion'] }, async () => buildOrders('', {}));

route('PATCH', '/api/admin/pedidos/:id/estado', { auth: 'emp', perms: ['pedidos'] }, async (ctx) => {
  if (!ESTADOS_PEDIDO.includes(ctx.body.estado)) throw bad('El estado no es válido.');
  await exec('dbo.usp_CambiarEstadoPedido', { IdPedido: parseInt(ctx.params.id, 10), Estado: ctx.body.estado });
  return { ok: true };
});

route('GET', '/api/admin/ganancias', { auth: 'emp', perms: ['ganancias'] }, async (ctx) => {
  const per = PERIODOS[ctx.query.periodo] || PERIODOS.mes;
  const rows = await query(
    `SELECT ${per.col} AS periodo, Pedidos AS pedidos, VentaNeta AS v, Costo AS c FROM dbo.${per.vista} ORDER BY ${per.orden} DESC`);
  const top = await query(
    `SELECT TOP 10 Producto AS name, Unidades AS qty, VentaNeta AS v, Costo AS c FROM dbo.vw_GananciaPorProducto ORDER BY Ganancia DESC`);
  const tot = await query(`SELECT ISNULL(SUM(VentaNeta), 0) AS v, ISNULL(SUM(Costo), 0) AS c FROM dbo.vw_LineasGanancia`);
  return { rows: rows.recordset, productos: top.recordset, total: tot.recordset[0] };
});

route('GET', '/api/admin/empleados', { auth: 'emp', perms: ['empleados'] }, async () => {
  const r = await query(`SELECT e.IdEmpleado AS id, e.Usuario AS [user], e.NombreCompleto AS name, r.Nombre AS role, e.Activo AS activo
                         FROM dbo.Empleados e JOIN dbo.Roles r ON r.IdRol = e.IdRol ORDER BY e.IdEmpleado`);
  return r.recordset;
});

function empData(b, claveObligatoria) {
  const clave = b.clave ? str(b.clave, 100, 'la contraseña') : null;
  if (claveObligatoria && !clave) throw bad('Falta la contraseña.');
  if (clave && clave.length < 4) throw bad('La contraseña debe tener al menos 4 caracteres.');
  return { Usuario: str(b.usuario, 30, 'el usuario'), Nombre: str(b.nombre, 100, 'el nombre'), Rol: str(b.rol, 30, 'el rol'), Clave: clave };
}
route('POST', '/api/admin/empleados', { auth: 'emp', perms: ['empleados'] }, async (ctx) => {
  await exec('dbo.usp_CrearEmpleado', { ...empData(ctx.body, true), RolSolicitante: ctx.user.role });
  return { ok: true };
});
route('PUT', '/api/admin/empleados/:id', { auth: 'emp', perms: ['empleados'] }, async (ctx) => {
  await exec('dbo.usp_ActualizarEmpleado', { IdEmpleado: parseInt(ctx.params.id, 10), ...empData(ctx.body, false), RolSolicitante: ctx.user.role });
  return { ok: true };
});
route('DELETE', '/api/admin/empleados/:id', { auth: 'emp', perms: ['empleados'] }, async (ctx) => {
  await exec('dbo.usp_EliminarEmpleado', { IdEmpleado: parseInt(ctx.params.id, 10), IdSolicitante: ctx.user.id, RolSolicitante: ctx.user.role });
  return { ok: true };
});

route('GET', '/api/admin/arrepentimientos', { auth: 'emp', perms: ['arrepentimientos'] }, async () => {
  const r = await query(`SELECT IdArrepentimiento AS id, CONVERT(VARCHAR(19), Fecha, 126) AS date, Nombre AS nombre, Email AS email,
                                NumeroCompra AS pedido, ISNULL(MontoReembolso, 0) AS monto, Estado AS estado
                         FROM dbo.vw_Arrepentimientos ORDER BY Fecha, IdArrepentimiento`);
  return r.recordset.map((x) => ({ ...x, nombre: x.nombre || '' }));
});
route('PATCH', '/api/admin/arrepentimientos/:id/estado', { auth: 'emp', perms: ['arrepentimientos'] }, async (ctx) => {
  if (!ESTADOS_ARREP.includes(ctx.body.estado)) throw bad('El estado no es válido.');
  await exec('dbo.usp_CambiarEstadoArrepentimiento', { IdArrepentimiento: parseInt(ctx.params.id, 10), Estado: ctx.body.estado });
  return { ok: true };
});

route('GET', '/api/admin/newsletter', { auth: 'emp', perms: ['newsletter'] }, async () => {
  const r = await query(`SELECT Email AS email, CONVERT(VARCHAR(19), Fecha, 126) AS date FROM dbo.Suscriptores ORDER BY Fecha, IdSuscriptor`);
  return r.recordset;
});
route('DELETE', '/api/admin/newsletter', { auth: 'emp', perms: ['newsletter'] }, async (ctx) => {
  if (!isEmail(ctx.body.email)) throw bad('Email inválido.');
  await exec('dbo.usp_QuitarSuscriptor', { Email: ctx.body.email.trim().toLowerCase() });
  return { ok: true };
});

module.exports = { routes, HttpError };
