# Nexo Tech

Tienda online de electrónica con panel de empleados. Proyecto de e-commerce hecho con **HTML + JavaScript**, un servidor **Node.js** y una base de datos **SQL Server**.

- **Tienda:** catálogo con menú de categorías, buscador y filtros, favoritos, carrito y confirmación de pedido. **Para comprar no hace falta crear una cuenta** (la cuenta es opcional y guarda el historial de pedidos).
- **Panel de empleados** (se entra con *Iniciar sesión*): según el rol se ven los informes de ventas y la facturación, se cambia el estado de los pedidos, se agrega stock, se modifican precios y se da de alta y de baja a productos. Las **ganancias** solo las ve el dueño.
- **Otros:** botón de arrepentimiento, newsletter y gestión de empleados con roles.

> El catálogo tiene 38 productos con sus precios, descuentos, stock y descripciones, y 7 productos más (Galaxy S26 Ultra, iPhone 18 Pro, HP táctil, Acer Swift Go 16, Apple Watch Ultra 3, Garmin Fenix 8 Pro y Echo Dot 5). Los precios de esos 7 son de referencia y su stock es de ejemplo: se ajustan desde el panel (*Precio* y *+ Stock*). Los datos de contacto y la sucursal son de ejemplo, y el costo de cada producto es un valor de demostración.

## Requisitos

- Node.js 18 o superior
- SQL Server 2017 o superior (Express alcanza)

## Puesta en marcha

1. **Crear la base.** En SSMS ejecutá `sql/01_base_de_datos.sql` (crea la base `EcommerceBanfield`, las tablas, los datos de ejemplo y los procedimientos; **si la base ya existe, la reemplaza**). Después ejecutá `sql/02_usuario_de_la_app.sql`, cambiando antes la contraseña. Si ya tenés la base cargada y solo querés actualizar las descripciones de los productos, ejecutá `sql/03_actualizar_descripciones.sql` (no borra nada; cambiá la línea `USE` si tu base tiene otro nombre). Para agregar los 7 productos nuevos a una base ya cargada, ejecutá `sql/04_agregar_productos.sql`.
2. **Configurar.** Copiá `.env.example` como `.env` y completá los datos de conexión y `TOKEN_SECRET` (un texto largo y aleatorio).
3. **Instalar y arrancar.**

   ```bash
   npm install
   npm start
   ```

4. Abrí <http://localhost:3000>.

### Usuarios de prueba del personal

| Usuario | Contraseña | Rol |
|---|---|---|
| `dueno` | `dueno123` | Dueño (ve las ganancias) |
| `gerente` | `gerente123` | Gerente |
| `admin` | `admin123` | Administrativo |
| `cajero` | `cajero123` | Cajero/a |
| `repositor` | `repo123` | Repositor |

**Cambialos antes de publicar el sitio.**

## Pruebas

```bash
npm test
```

Son 13 pruebas automáticas del servidor (permisos, validaciones, login, errores y seguridad). Usan una base simulada, así que no necesitan SQL Server.

## Estructura

```
sql/       01_base_de_datos.sql, 02_usuario_de_la_app.sql, 03_actualizar_descripciones.sql y 04_agregar_productos.sql (opcionales)
server/    index.js (HTTP y sesión), routes.js (API), auth.js, db.js
public/    index.html (la tienda y el panel, conectados al servidor)
demo/      electro-banfield.html (versión de demostración que funciona sola, sin servidor ni base)
test/      pruebas automáticas del servidor
docs/      documentación técnica (Word y Markdown) y diagrama de la base de datos
docs/marca/ logo e isologo de Nexo Tech
```

## Documentación

- [Documentación técnica](docs/documentacion-tecnica.md) (también en `docs/documentacion-tecnica.docx`)
- Diagrama de la base de datos: `docs/er.png` (se regenera con `docs/generar_diagrama.py`)

## Ramas

| Rama | Para qué se usa |
|---|---|
| `main` | Versión estable (lo que se entrega). Cada versión tiene una etiqueta (`v1.0.0`). |
| `develop` | Integración: acá se juntan las funcionalidades terminadas. |
| `feature/base-de-datos` | Tablas, vistas, procedimientos y datos de ejemplo. |
| `feature/servidor-api` | Servidor Node.js, API, sesiones y permisos. |
| `feature/tienda-web` | La tienda, el panel de empleados y la versión de demostración. |
| `docs/documentacion` | Documentación y diagrama. |

Flujo de trabajo: se crea una rama `feature/...` desde `develop`, se trabaja ahí, se integra en `develop` y, cuando está probado, `develop` se integra en `main`.

## Limitaciones conocidas

- El script SQL no se probó en un SQL Server real durante el desarrollo: la primera ejecución hay que revisarla.
- No hay pago real, emails automáticos, stock por versión ni recuperación de contraseña.
- Para publicarlo en internet hay que usar HTTPS (por ejemplo con Nginx) y cambiar los usuarios y claves de prueba.
