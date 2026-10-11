/* =====================================================================
   ELECTRO BANFIELD (tienda de electrónica) - Base de datos para SQL Server
   Requiere SQL Server 2017 o superior (usa OPENJSON, STRING_AGG y CREATE OR ALTER).

   Cómo usarlo: abrilo en SSMS (o Azure Data Studio) y ejecutalo completo (F5).
   ATENCIÓN: si ya existe una base EcommerceBanfield, este script LA BORRA
   y la vuelve a crear desde cero.

   Contenido:
     1. Creación de la base (con cuentas de clientes, roles/permisos, costos y ganancias)
     2. Tablas, claves y restricciones
     3. Índices
     4. Datos iniciales (roles, empleados, productos, parámetros)
     5. Vistas para reportes (ventas y facturación diaria/semanal/mensual/anual)
     6. Procedimientos almacenados (registrar pedido, login, estados, arrepentimiento)
     7. Pedidos de ejemplo (opcional)
   ===================================================================== */

USE master;
GO
IF DB_ID(N'EcommerceBanfield') IS NOT NULL
BEGIN
    ALTER DATABASE EcommerceBanfield SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EcommerceBanfield;
END
GO
CREATE DATABASE EcommerceBanfield COLLATE Modern_Spanish_CI_AI;
GO
USE EcommerceBanfield;
GO

/* =====================================================================
   2. TABLAS
   ===================================================================== */

-- ---------- Empleados, roles y permisos ----------
CREATE TABLE dbo.Roles (
    IdRol       INT IDENTITY(1,1) CONSTRAINT PK_Roles PRIMARY KEY,
    Nombre      NVARCHAR(30)  NOT NULL CONSTRAINT UQ_Roles_Nombre UNIQUE,
    Descripcion NVARCHAR(200) NULL
);

CREATE TABLE dbo.RolPermisos (
    IdRol   INT          NOT NULL CONSTRAINT FK_RolPermisos_Roles REFERENCES dbo.Roles(IdRol),
    Permiso NVARCHAR(20) NOT NULL
        CONSTRAINT CK_RolPermisos_Permiso CHECK (Permiso IN (N'ventas', N'pedidos', N'facturacion', N'ganancias', N'arrepentimientos', N'newsletter', N'stock', N'precios', N'altabaja', N'empleados')),
    CONSTRAINT PK_RolPermisos PRIMARY KEY (IdRol, Permiso)
);

CREATE TABLE dbo.Empleados (
    IdEmpleado     INT IDENTITY(1,1) CONSTRAINT PK_Empleados PRIMARY KEY,
    Usuario        NVARCHAR(30)  NOT NULL CONSTRAINT UQ_Empleados_Usuario UNIQUE,
    NombreCompleto NVARCHAR(100) NOT NULL,
    IdRol          INT           NOT NULL CONSTRAINT FK_Empleados_Roles REFERENCES dbo.Roles(IdRol),
    ClaveSalt      VARBINARY(16) NOT NULL,
    ClaveHash      VARBINARY(32) NOT NULL,   -- SHA2_256(salt + clave). Nunca se guarda la clave en texto plano.
    Activo         BIT           NOT NULL CONSTRAINT DF_Empleados_Activo DEFAULT 1,
    FechaAlta      DATETIME2(0)  NOT NULL CONSTRAINT DF_Empleados_FechaAlta DEFAULT SYSDATETIME()
);

-- ---------- Catálogo ----------
CREATE TABLE dbo.Categorias (
    IdCategoria INT IDENTITY(1,1) CONSTRAINT PK_Categorias PRIMARY KEY,
    Nombre      NVARCHAR(50) NOT NULL CONSTRAINT UQ_Categorias_Nombre UNIQUE
);

CREATE TABLE dbo.TiposProducto (
    IdTipo INT IDENTITY(1,1) CONSTRAINT PK_TiposProducto PRIMARY KEY,
    Codigo NVARCHAR(20) NOT NULL CONSTRAINT UQ_TiposProducto_Codigo UNIQUE,
    Nombre NVARCHAR(60) NOT NULL
);

-- Versiones: capacidad (128 GB), pulgadas (55"), etc.
CREATE TABLE dbo.Versiones (
    IdVersion INT IDENTITY(1,1) CONSTRAINT PK_Versiones PRIMARY KEY,
    Nombre  NVARCHAR(30) NOT NULL CONSTRAINT UQ_Versiones_Nombre UNIQUE,
    Orden   INT          NOT NULL
);

CREATE TABLE dbo.Colores (
    IdColor INT IDENTITY(1,1) CONSTRAINT PK_Colores PRIMARY KEY,
    Nombre  NVARCHAR(30) NOT NULL CONSTRAINT UQ_Colores_Nombre UNIQUE
);

CREATE TABLE dbo.Productos (
    IdProducto          INT IDENTITY(1,1) CONSTRAINT PK_Productos PRIMARY KEY,
    Nombre              NVARCHAR(150) NOT NULL,
    Descripcion         NVARCHAR(500) NULL,
    IdCategoria         INT NOT NULL CONSTRAINT FK_Productos_Categorias REFERENCES dbo.Categorias(IdCategoria),
    IdTipo              INT NULL     CONSTRAINT FK_Productos_Tipos REFERENCES dbo.TiposProducto(IdTipo),
    Marca               NVARCHAR(30) NULL,
    Anio                CHAR(4) NULL   -- año de lanzamiento
        CONSTRAINT CK_Productos_Anio CHECK (Anio IS NULL OR Anio LIKE '[0-9][0-9][0-9][0-9]'),
    PrecioNeto          DECIMAL(12,2) NOT NULL CONSTRAINT CK_Productos_Neto CHECK (PrecioNeto >= 0),
    CostoNeto           DECIMAL(12,2) NOT NULL CONSTRAINT DF_Productos_Costo DEFAULT 0 CONSTRAINT CK_Productos_Costo CHECK (CostoNeto >= 0),  -- solo lo ve el dueño
    IvaPorcentaje       DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Productos_Iva DEFAULT 21
        CONSTRAINT CK_Productos_Iva CHECK (IvaPorcentaje BETWEEN 0 AND 100),
    DescuentoPorcentaje DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Productos_Desc DEFAULT 0
        CONSTRAINT CK_Productos_Desc CHECK (DescuentoPorcentaje BETWEEN 0 AND 100),
    Stock               INT NOT NULL CONSTRAINT DF_Productos_Stock DEFAULT 0
        CONSTRAINT CK_Productos_Stock CHECK (Stock >= 0),
    Emoji               NVARCHAR(8)   NULL,
    ImagenUrl           NVARCHAR(500) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT 1,
    FechaAlta           DATETIME2(0) NOT NULL CONSTRAINT DF_Productos_FechaAlta DEFAULT SYSDATETIME(),
    -- Precio al público (neto + IVA) y precio final (con descuento): se calculan solos.
    PrecioPublico AS CAST(PrecioNeto * (1 + IvaPorcentaje / 100.0) AS DECIMAL(12,2)) PERSISTED,
    PrecioFinal   AS CAST(PrecioNeto * (1 + IvaPorcentaje / 100.0) * (1 - DescuentoPorcentaje / 100.0) AS DECIMAL(12,2)) PERSISTED
);

CREATE TABLE dbo.ProductoVersiones (
    IdProducto INT NOT NULL CONSTRAINT FK_ProductoVersiones_Productos REFERENCES dbo.Productos(IdProducto) ON DELETE CASCADE,
    IdVersion  INT NOT NULL CONSTRAINT FK_ProductoVersiones_Versiones REFERENCES dbo.Versiones(IdVersion),
    CONSTRAINT PK_ProductoVersiones PRIMARY KEY (IdProducto, IdVersion)
);

CREATE TABLE dbo.ProductoColores (
    IdProducto INT NOT NULL CONSTRAINT FK_ProductoColores_Productos REFERENCES dbo.Productos(IdProducto) ON DELETE CASCADE,
    IdColor    INT NOT NULL CONSTRAINT FK_ProductoColores_Colores REFERENCES dbo.Colores(IdColor),
    CONSTRAINT PK_ProductoColores PRIMARY KEY (IdProducto, IdColor)
);

-- ---------- Clientes y pedidos ----------
CREATE TABLE dbo.Clientes (
    IdCliente INT IDENTITY(1,1) CONSTRAINT PK_Clientes PRIMARY KEY,
    Nombre    NVARCHAR(100) NOT NULL,
    Email     NVARCHAR(150) NOT NULL CONSTRAINT UQ_Clientes_Email UNIQUE,
    Telefono  NVARCHAR(30)  NULL,
    ClaveSalt VARBINARY(16) NULL,   -- NULL = compró como invitado (sin cuenta)
    ClaveHash VARBINARY(32) NULL,   -- SHA2_256(sal + clave); nunca se guarda la clave en texto plano
    FechaCuenta DATETIME2(0) NULL,
    FechaAlta DATETIME2(0)  NOT NULL CONSTRAINT DF_Clientes_FechaAlta DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.Pedidos (
    IdPedido         INT IDENTITY(1000,1) CONSTRAINT PK_Pedidos PRIMARY KEY,
    IdCliente        INT NOT NULL CONSTRAINT FK_Pedidos_Clientes REFERENCES dbo.Clientes(IdCliente),
    Fecha            DATETIME2(0) NOT NULL CONSTRAINT DF_Pedidos_Fecha DEFAULT SYSDATETIME(),
    Estado           NVARCHAR(15) NOT NULL CONSTRAINT DF_Pedidos_Estado DEFAULT N'pendiente'
        CONSTRAINT CK_Pedidos_Estado CHECK (Estado IN (N'pendiente', N'pagado', N'enviado', N'entregado', N'cancelado')),
    Retiro           BIT NOT NULL,                 -- 1 = retira en el local, 0 = envío a domicilio
    DireccionEntrega NVARCHAR(200) NULL,
    Subtotal         DECIMAL(14,2) NOT NULL,       -- productos con IVA, antes de descuento y envío
    Descuento        DECIMAL(14,2) NOT NULL CONSTRAINT DF_Pedidos_Descuento DEFAULT 0,   -- reservado para cupones
    Envio            DECIMAL(14,2) NOT NULL CONSTRAINT DF_Pedidos_Envio DEFAULT 0,
    Neto             DECIMAL(14,2) NOT NULL,
    Iva              DECIMAL(14,2) NOT NULL,
    Total            DECIMAL(14,2) NOT NULL,
    CONSTRAINT CK_Pedidos_Direccion CHECK (Retiro = 1 OR DireccionEntrega IS NOT NULL),
    CONSTRAINT CK_Pedidos_Montos CHECK (Subtotal >= 0 AND Descuento >= 0 AND Envio >= 0 AND Total >= 0)
);

CREATE TABLE dbo.DetallePedido (
    IdDetalle             INT IDENTITY(1,1) CONSTRAINT PK_DetallePedido PRIMARY KEY,
    IdPedido              INT NOT NULL CONSTRAINT FK_Detalle_Pedidos REFERENCES dbo.Pedidos(IdPedido) ON DELETE CASCADE,
    IdProducto            INT NOT NULL CONSTRAINT FK_Detalle_Productos REFERENCES dbo.Productos(IdProducto),
    IdVersion             INT NULL CONSTRAINT FK_Detalle_Versiones REFERENCES dbo.Versiones(IdVersion),
    IdColor               INT NULL CONSTRAINT FK_Detalle_Colores REFERENCES dbo.Colores(IdColor),
    Cantidad              INT NOT NULL CONSTRAINT CK_Detalle_Cantidad CHECK (Cantidad > 0),
    PrecioNetoUnitario    DECIMAL(14,4) NOT NULL,   -- precio al momento de la compra (ya con descuento)
    CostoUnitario         DECIMAL(14,4) NOT NULL CONSTRAINT DF_Detalle_Costo DEFAULT 0,  -- costo al momento de la compra
    IvaPorcentaje         DECIMAL(5,2)  NOT NULL,
    TotalLinea AS CAST(PrecioNetoUnitario * (1 + IvaPorcentaje / 100.0) * Cantidad AS DECIMAL(14,2)) PERSISTED
);

-- ---------- Otros ----------
CREATE TABLE dbo.Suscriptores (
    IdSuscriptor INT IDENTITY(1,1) CONSTRAINT PK_Suscriptores PRIMARY KEY,
    Email        NVARCHAR(150) NOT NULL CONSTRAINT UQ_Suscriptores_Email UNIQUE,
    Fecha        DATETIME2(0)  NOT NULL CONSTRAINT DF_Suscriptores_Fecha DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.Arrepentimientos (
    IdArrepentimiento INT IDENTITY(1,1) CONSTRAINT PK_Arrepentimientos PRIMARY KEY,
    Nombre            NVARCHAR(100) NULL,
    Email             NVARCHAR(150) NOT NULL,
    MontoReembolso    DECIMAL(14,2) NULL,
    NumeroCompra      NVARCHAR(30)  NOT NULL,
    IdPedido          INT NULL CONSTRAINT FK_Arrepentimientos_Pedidos REFERENCES dbo.Pedidos(IdPedido),
    Estado            NVARCHAR(15) NOT NULL CONSTRAINT DF_Arrepentimientos_Estado DEFAULT N'recibida'
        CONSTRAINT CK_Arrepentimientos_Estado CHECK (Estado IN (N'recibida', N'en proceso', N'resuelta')),
    Fecha             DATETIME2(0) NOT NULL CONSTRAINT DF_Arrepentimientos_Fecha DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.Parametros (
    Clave       NVARCHAR(40)  NOT NULL CONSTRAINT PK_Parametros PRIMARY KEY,
    Valor       DECIMAL(14,2) NOT NULL,
    Descripcion NVARCHAR(200) NULL
);
GO

/* =====================================================================
   3. ÍNDICES
   ===================================================================== */
CREATE INDEX IX_Productos_Categoria ON dbo.Productos (IdCategoria);
CREATE INDEX IX_Productos_Filtros   ON dbo.Productos (Marca, IdTipo, Anio) INCLUDE (Stock);
CREATE INDEX IX_Pedidos_Fecha       ON dbo.Pedidos (Fecha) INCLUDE (Estado, Neto, Iva, Total);
CREATE INDEX IX_Pedidos_Cliente     ON dbo.Pedidos (IdCliente);
CREATE INDEX IX_Detalle_Pedido      ON dbo.DetallePedido (IdPedido);
CREATE INDEX IX_Detalle_Producto    ON dbo.DetallePedido (IdProducto);
GO

/* =====================================================================
   4. DATOS INICIALES
   ===================================================================== */
INSERT dbo.Roles (Nombre, Descripcion) VALUES
    (N'dueno',          N'Dueño: todo, y es el único que ve las ganancias y los costos'),
    (N'gerente',        N'Informes, stock, precios, alta/baja de productos y empleados'),
    (N'administrativo', N'Informes, stock y precios'),
    (N'cajero',         N'Informe de ventas'),
    (N'repositor',      N'Agregar stock');

INSERT dbo.RolPermisos (IdRol, Permiso)
SELECT r.IdRol, m.Permiso
FROM dbo.Roles r
JOIN (VALUES
    (N'dueno', N'ventas'), (N'dueno', N'facturacion'), (N'dueno', N'ganancias'), (N'dueno', N'stock'),
    (N'dueno', N'precios'), (N'dueno', N'altabaja'), (N'dueno', N'empleados'),
    (N'dueno', N'pedidos'), (N'dueno', N'arrepentimientos'), (N'dueno', N'newsletter'),
    (N'gerente', N'ventas'), (N'gerente', N'facturacion'), (N'gerente', N'stock'),
    (N'gerente', N'precios'), (N'gerente', N'altabaja'), (N'gerente', N'empleados'),
    (N'gerente', N'pedidos'), (N'gerente', N'arrepentimientos'), (N'gerente', N'newsletter'),
    (N'administrativo', N'ventas'), (N'administrativo', N'facturacion'), (N'administrativo', N'stock'), (N'administrativo', N'precios'),
    (N'administrativo', N'pedidos'), (N'administrativo', N'arrepentimientos'), (N'administrativo', N'newsletter'),
    (N'cajero', N'ventas'), (N'cajero', N'pedidos'),
    (N'repositor', N'stock')
) m (Rol, Permiso) ON m.Rol = r.Nombre;

INSERT dbo.Categorias (Nombre) VALUES
    (N'Celulares'),
    (N'Computación'),
    (N'Audio'),
    (N'TV y video'),
    (N'Gaming'),
    (N'Hogar inteligente'),
    (N'Accesorios');

INSERT dbo.TiposProducto (Codigo, Nombre) VALUES
    (N'celular', N'Celular'),
    (N'tablet', N'Tablet'),
    (N'smartwatch', N'Smartwatch'),
    (N'notebook', N'Notebook'),
    (N'monitor', N'Monitor'),
    (N'periferico', N'Teclado, mouse y periféricos'),
    (N'almacenamiento', N'Almacenamiento (SSD, pendrive)'),
    (N'impresora', N'Impresora'),
    (N'auriculares', N'Auriculares'),
    (N'parlante', N'Parlantes y barras de sonido'),
    (N'tv', N'Televisor'),
    (N'proyector', N'Proyector'),
    (N'consola', N'Consola'),
    (N'joystick', N'Joystick'),
    (N'domotica', N'Hogar inteligente'),
    (N'camara', N'Cámara de seguridad'),
    (N'accesorio', N'Accesorio');

INSERT dbo.Versiones (Nombre, Orden) VALUES
    (N'128 GB', 1),
    (N'256 GB', 2),
    (N'512 GB', 3),
    (N'64 GB', 4),
    (N'256 GB SSD', 5),
    (N'512 GB SSD', 6),
    (N'1 TB SSD', 7),
    (N'500 GB', 8),
    (N'1 TB', 9),
    (N'2 TB', 10),
    (N'43"', 11),
    (N'50"', 12),
    (N'55"', 13),
    (N'65"', 14),
    (N'825 GB', 15);

INSERT dbo.Colores (Nombre) VALUES (N'Negro'), (N'Plata'), (N'Verde'), (N'Azul'), (N'Gris'), (N'Rosa'), (N'Blanco');

INSERT dbo.Parametros (Clave, Valor, Descripcion) VALUES
    (N'IVA_GENERAL',            21,     N'IVA general en %'),
    (N'ENVIO_GRATIS_DESDE',     250000, N'Subtotal desde el cual el envío a domicilio es gratis'),
    (N'COSTO_ENVIO',            9000,   N'Costo del envío a domicilio por debajo del mínimo (valor de demo)'),
    (N'STOCK_BAJO',             5,      N'Stock a partir del cual se considera bajo');

-- Productos (precio neto = precio al público / 1,21). El IdProducto sigue el orden de la lista.
INSERT dbo.Productos (Nombre, Descripcion, IdCategoria, IdTipo, Marca, Anio,
                      PrecioNeto, IvaPorcentaje, DescuentoPorcentaje, Stock, CostoNeto, Emoji)
SELECT v.Nombre, v.Descripcion, c.IdCategoria, t.IdTipo, v.Marca, v.Anio,
       v.Neto, v.Iva, v.Descuento, v.Stock, v.Costo, v.Emoji
FROM (VALUES
    (1, N'Smartphone Nova X12 128 GB', N'Smartphone con pantalla nítida, cámara de alta resolución y batería para todo el día.', N'Celulares', N'celular', N'Nova', N'2026', 536363.64, 21, 0, 4, 386181.82, N'📱'),
    (2, N'Smartphone Nova X12 Pro 256 GB', N'Smartphone con pantalla nítida, cámara de alta resolución y batería para todo el día.', N'Celulares', N'celular', N'Nova', N'2026', 742975.21, 21, 0, 11, 631528.93, N'📱'),
    (3, N'Smartphone Orbix A7 128 GB', N'Smartphone con pantalla nítida, cámara de alta resolución y batería para todo el día.', N'Celulares', N'celular', N'Orbix', N'2025', 321487.60, 21, 15, 18, 266834.71, N'📱'),
    (4, N'Smartphone Kairo Lite 64 GB', N'Smartphone con pantalla nítida, cámara de alta resolución y batería para todo el día.', N'Celulares', N'celular', N'Kairo', N'2025', 180991.74, 21, 10, 25, 146603.31, N'📱'),
    (5, N'Tablet Orbix Tab 10" 64 GB', N'Tablet liviana para estudiar, trabajar y mirar series.', N'Celulares', N'tablet', N'Orbix', N'2025', 247107.44, 21, 0, 3, 195214.88, N'📲'),
    (6, N'Smartwatch Vektra Fit 2', N'Reloj inteligente con seguimiento de actividad y notificaciones.', N'Celulares', N'smartwatch', N'Vektra', N'2026', 106611.57, 21, 20, 16, 82090.91, N'⌚'),
    (7, N'Notebook Vektra Book 15" Core i5 8 GB', N'Notebook liviana para estudio y trabajo, con arranque rápido.', N'Computación', N'notebook', N'Vektra', N'2026', 660330.58, 21, 0, 23, 495247.93, N'💻'),
    (8, N'Notebook Vektra Book Pro 14" 16 GB', N'Notebook liviana para estudio y trabajo, con arranque rápido.', N'Computación', N'notebook', N'Vektra', N'2026', 983471.07, 21, 0, 7, 717933.88, N'💻'),
    (9, N'Notebook Lumen Go 14" 4 GB', N'Notebook liviana para estudio y trabajo, con arranque rápido.', N'Computación', N'notebook', N'Lumen', N'2025', 379338.84, 21, 12, 14, 326231.40, N'💻'),
    (10, N'Monitor Lumen 24" Full HD', N'Monitor con colores vivos y conexión HDMI.', N'Computación', N'monitor', N'Lumen', N'2025', 156198.35, 21, 0, 21, 131206.61, N'🖥️'),
    (11, N'Monitor Lumen Curvo 27" 144 Hz', N'Monitor con colores vivos y conexión HDMI.', N'Computación', N'monitor', N'Lumen', N'2026', 271900.83, 21, 10, 5, 222958.68, N'🖥️'),
    (12, N'Teclado mecánico Kairo K87', N'Periférico de conexión simple y uso cómodo.', N'Computación', N'periferico', N'Kairo', N'2025', 57024.79, 21, 0, 12, 45619.83, N'⌨️'),
    (13, N'Mouse inalámbrico Kairo M3', N'Periférico de conexión simple y uso cómodo.', N'Computación', N'periferico', N'Kairo', N'2025', 19834.71, 21, 0, 19, 15471.07, N'🖱️'),
    (14, N'Disco SSD Orbix', N'Almacenamiento rápido y confiable para tus archivos.', N'Computación', N'almacenamiento', N'Orbix', N'2025', 81818.18, 21, 15, 3, 62181.82, N'💾'),
    (15, N'Pendrive Orbix USB 3.2', N'Almacenamiento rápido y confiable para tus archivos.', N'Computación', N'almacenamiento', N'Orbix', N'2025', 11983.47, 21, 0, 10, 8867.77, N'💾'),
    (16, N'Impresora multifunción Lumen Ink', N'Impresora multifunción: imprime, copia y escanea.', N'Computación', N'impresora', N'Lumen', N'2025', 180991.74, 21, 0, 17, 130314.05, N'🖨️'),
    (17, N'Auriculares inalámbricos Nova Buds', N'Auriculares con sonido claro y diseño cómodo.', N'Audio', N'auriculares', N'Nova', N'2026', 73553.72, 21, 10, 24, 62520.66, N'🎧'),
    (18, N'Auriculares over-ear Vektra Studio', N'Auriculares con sonido claro y diseño cómodo.', N'Audio', N'auriculares', N'Vektra', N'2025', 123140.50, 21, 0, 8, 102206.61, N'🎧'),
    (19, N'Parlante Bluetooth Orbix Boom', N'Sonido potente para tu casa o para llevar.', N'Audio', N'parlante', N'Orbix', N'2025', 65289.26, 21, 20, 15, 52884.30, N'🔊'),
    (20, N'Barra de sonido Lumen 2.1', N'Sonido potente para tu casa o para llevar.', N'Audio', N'parlante', N'Lumen', N'2026', 156198.35, 21, 0, 22, 123396.69, N'🔊'),
    (21, N'Smart TV Lumen 4K', N'Smart TV con imagen nítida y aplicaciones de streaming.', N'TV y video', N'tv', N'Lumen', N'2026', 379338.84, 21, 10, 6, 292090.91, N'📺'),
    (22, N'Smart TV Lumen QLED 4K', N'Smart TV con imagen nítida y aplicaciones de streaming.', N'TV y video', N'tv', N'Lumen', N'2026', 619008.26, 21, 0, 13, 464256.20, N'📺'),
    (23, N'Smart TV Orbix HD 32"', N'Smart TV con imagen nítida y aplicaciones de streaming.', N'TV y video', N'tv', N'Orbix', N'2025', 189256.20, 21, 15, 3, 138157.02, N'📺'),
    (24, N'Proyector Vektra Beam', N'Proyector para series, juegos y reuniones.', N'TV y video', N'proyector', N'Vektra', N'2025', 247107.44, 21, 0, 4, 212512.40, N'📽️'),
    (25, N'Consola Kairo Play', N'Consola de videojuegos con gráficos fluidos y carga rápida.', N'Gaming', N'consola', N'Kairo', N'2026', 742975.21, 21, 0, 11, 624099.17, N'🎮'),
    (26, N'Joystick inalámbrico Kairo Pad', N'Joystick ergonómico de conexión inalámbrica.', N'Gaming', N'joystick', N'Kairo', N'2025', 65289.26, 21, 10, 18, 53537.19, N'🕹️'),
    (27, N'Auriculares gamer Vektra Pro', N'Auriculares con sonido claro y diseño cómodo.', N'Gaming', N'auriculares', N'Vektra', N'2025', 81818.18, 21, 0, 25, 65454.55, N'🎧'),
    (28, N'Mouse gamer Vektra RGB', N'Periférico de conexión simple y uso cómodo.', N'Gaming', N'periferico', N'Vektra', N'2026', 37190.08, 21, 0, 9, 29008.26, N'🖱️'),
    (29, N'Lámpara inteligente Lumen Smart', N'Dispositivo para automatizar tu casa desde el celular.', N'Hogar inteligente', N'domotica', N'Lumen', N'2025', 15289.26, 21, 0, 16, 11619.83, N'💡'),
    (30, N'Enchufe inteligente Lumen Plug', N'Dispositivo para automatizar tu casa desde el celular.', N'Hogar inteligente', N'domotica', N'Lumen', N'2025', 10661.16, 21, 0, 23, 7889.26, N'🔌'),
    (31, N'Cámara de seguridad Kairo Eye 2K', N'Cámara de seguridad con visión nocturna y alertas en el celular.', N'Hogar inteligente', N'camara', N'Kairo', N'2026', 48760.33, 21, 0, 7, 35107.44, N'📷'),
    (32, N'Asistente de voz Nova Home', N'Dispositivo para automatizar tu casa desde el celular.', N'Hogar inteligente', N'domotica', N'Nova', N'2026', 57024.79, 21, 15, 3, 48471.07, N'📡'),
    (33, N'Cargador rápido Nova 65 W', N'Accesorio práctico para el día a día.', N'Accesorios', N'accesorio', N'Nova', N'2026', 23966.94, 21, 0, 21, 19892.56, N'🔌'),
    (34, N'Cable USB-C a USB-C 2 m', N'Accesorio práctico para el día a día.', N'Accesorios', N'accesorio', N'Nova', N'2025', 7355.37, 21, 0, 5, 5957.85, N'🔗'),
    (35, N'Funda para notebook 15"', N'Accesorio práctico para el día a día.', N'Accesorios', N'accesorio', N'Vektra', N'2025', 16446.28, 21, 0, 12, 12992.56, N'💼'),
    (36, N'Power bank Orbix 20.000 mAh', N'Accesorio práctico para el día a día.', N'Accesorios', N'accesorio', N'Orbix', N'2026', 32231.40, 21, 10, 19, 24818.18, N'🔋'),
    (37, N'Soporte para celular de auto', N'Accesorio práctico para el día a día.', N'Accesorios', N'accesorio', N'Kairo', N'2025', 10330.58, 21, 0, 26, 7747.93, N'🚗')
) v (Orden, Nombre, Descripcion, Categoria, Tipo, Marca, Anio, Neto, Iva, Descuento, Stock, Costo, Emoji)
JOIN dbo.Categorias c ON c.Nombre = v.Categoria
LEFT JOIN dbo.TiposProducto t ON t.Codigo = v.Tipo
ORDER BY v.Orden;

-- Versiones y colores de cada producto
INSERT dbo.ProductoVersiones (IdProducto, IdVersion)
SELECT x.IdProducto, v.IdVersion
FROM (VALUES
    (1, N'128 GB'),
    (1, N'256 GB'),
    (2, N'256 GB'),
    (2, N'512 GB'),
    (3, N'64 GB'),
    (3, N'128 GB'),
    (4, N'64 GB'),
    (4, N'128 GB'),
    (5, N'64 GB'),
    (5, N'128 GB'),
    (7, N'256 GB SSD'),
    (7, N'512 GB SSD'),
    (8, N'512 GB SSD'),
    (8, N'1 TB SSD'),
    (9, N'128 GB'),
    (14, N'500 GB'),
    (14, N'1 TB'),
    (14, N'2 TB'),
    (15, N'64 GB'),
    (15, N'128 GB'),
    (15, N'256 GB'),
    (21, N'43"'),
    (21, N'50"'),
    (21, N'55"'),
    (22, N'55"'),
    (22, N'65"'),
    (25, N'825 GB'),
    (25, N'1 TB')
) x (IdProducto, Version)
JOIN dbo.Versiones v ON v.Nombre = x.Version;

INSERT dbo.ProductoColores (IdProducto, IdColor)
SELECT x.IdProducto, c.IdColor
FROM (VALUES
    (1, N'Negro'),
    (1, N'Plata'),
    (1, N'Verde'),
    (2, N'Negro'),
    (2, N'Plata'),
    (3, N'Negro'),
    (3, N'Azul'),
    (4, N'Negro'),
    (4, N'Azul'),
    (5, N'Gris'),
    (6, N'Negro'),
    (6, N'Rosa'),
    (7, N'Gris'),
    (8, N'Plata'),
    (9, N'Azul'),
    (12, N'Negro'),
    (12, N'Blanco'),
    (13, N'Negro'),
    (13, N'Blanco'),
    (13, N'Verde'),
    (17, N'Blanco'),
    (17, N'Negro'),
    (18, N'Negro'),
    (18, N'Plata'),
    (19, N'Negro'),
    (19, N'Azul'),
    (19, N'Verde'),
    (20, N'Negro'),
    (24, N'Blanco'),
    (25, N'Blanco'),
    (25, N'Negro'),
    (26, N'Negro'),
    (26, N'Blanco'),
    (26, N'Azul'),
    (27, N'Negro'),
    (28, N'Negro'),
    (29, N'Blanco'),
    (30, N'Blanco'),
    (31, N'Blanco'),
    (32, N'Gris'),
    (32, N'Negro'),
    (33, N'Blanco'),
    (33, N'Negro'),
    (34, N'Negro'),
    (35, N'Negro'),
    (35, N'Gris'),
    (36, N'Negro'),
    (37, N'Negro')
) x (IdProducto, Color)
JOIN dbo.Colores c ON c.Nombre = x.Color;
GO

/* =====================================================================
   5. VISTAS PARA REPORTES
   ===================================================================== */
CREATE OR ALTER VIEW dbo.vw_CatalogoProductos AS
SELECT p.IdProducto, p.Nombre, c.Nombre AS Categoria, t.Nombre AS Tipo, p.Marca, p.Anio,
       p.PrecioNeto, p.IvaPorcentaje, p.PrecioPublico, p.DescuentoPorcentaje, p.PrecioFinal, p.Stock, p.Activo
FROM dbo.Productos p
JOIN dbo.Categorias c ON c.IdCategoria = p.IdCategoria
LEFT JOIN dbo.TiposProducto t ON t.IdTipo = p.IdTipo;
GO

CREATE OR ALTER VIEW dbo.vw_StockBajo AS
SELECT p.IdProducto, p.Nombre, p.Stock
FROM dbo.Productos p
WHERE p.Activo = 1
  AND p.Stock <= (SELECT Valor FROM dbo.Parametros WHERE Clave = N'STOCK_BAJO');
GO

-- Listado general de ventas (una fila por pedido)
CREATE OR ALTER VIEW dbo.vw_ListadoVentas AS
SELECT p.IdPedido, p.Fecha, c.Nombre AS Cliente, c.Email, p.Estado, p.Total,
       (SELECT STRING_AGG(CONCAT(d.Cantidad, N'x ', pr.Nombre), N', ')
        FROM dbo.DetallePedido d
        JOIN dbo.Productos pr ON pr.IdProducto = d.IdProducto
        WHERE d.IdPedido = p.IdPedido) AS Productos
FROM dbo.Pedidos p
JOIN dbo.Clientes c ON c.IdCliente = p.IdCliente;
GO

-- Ventas por producto (para filtrar por fechas y producto)
CREATE OR ALTER VIEW dbo.vw_VentasDetalle AS
SELECT p.IdPedido, p.Fecha, p.Estado, c.Nombre AS Cliente,
       pr.IdProducto, pr.Nombre AS Producto, ve.Nombre AS Version, co.Nombre AS Color,
       d.Cantidad, d.PrecioNetoUnitario, d.TotalLinea
FROM dbo.DetallePedido d
JOIN dbo.Pedidos p   ON p.IdPedido = d.IdPedido
JOIN dbo.Clientes c  ON c.IdCliente = p.IdCliente
JOIN dbo.Productos pr ON pr.IdProducto = d.IdProducto
LEFT JOIN dbo.Versiones ve ON ve.IdVersion = d.IdVersion
LEFT JOIN dbo.Colores co ON co.IdColor = d.IdColor;
GO

-- Facturación (los pedidos cancelados no se cuentan)
CREATE OR ALTER VIEW dbo.vw_FacturacionDiaria AS
SELECT CAST(p.Fecha AS DATE) AS Periodo, COUNT(*) AS Pedidos,
       SUM(p.Neto) AS Neto, SUM(p.Iva) AS Iva, SUM(p.Total) AS Total
FROM dbo.Pedidos p
WHERE p.Estado <> N'cancelado'
GROUP BY CAST(p.Fecha AS DATE);
GO

-- Semana: se identifica por su lunes
CREATE OR ALTER VIEW dbo.vw_FacturacionSemanal AS
SELECT DATEADD(DAY, -(DATEDIFF(DAY, '19000101', f.D) % 7), f.D) AS InicioSemana, COUNT(*) AS Pedidos,
       SUM(p.Neto) AS Neto, SUM(p.Iva) AS Iva, SUM(p.Total) AS Total
FROM dbo.Pedidos p
CROSS APPLY (SELECT CAST(p.Fecha AS DATE) AS D) f
WHERE p.Estado <> N'cancelado'
GROUP BY DATEADD(DAY, -(DATEDIFF(DAY, '19000101', f.D) % 7), f.D);
GO

CREATE OR ALTER VIEW dbo.vw_FacturacionMensual AS
SELECT DATEFROMPARTS(YEAR(p.Fecha), MONTH(p.Fecha), 1) AS Mes, COUNT(*) AS Pedidos,
       SUM(p.Neto) AS Neto, SUM(p.Iva) AS Iva, SUM(p.Total) AS Total
FROM dbo.Pedidos p
WHERE p.Estado <> N'cancelado'
GROUP BY DATEFROMPARTS(YEAR(p.Fecha), MONTH(p.Fecha), 1);
GO

CREATE OR ALTER VIEW dbo.vw_FacturacionAnual AS
SELECT YEAR(p.Fecha) AS Anio, COUNT(*) AS Pedidos,
       SUM(p.Neto) AS Neto, SUM(p.Iva) AS Iva, SUM(p.Total) AS Total
FROM dbo.Pedidos p
WHERE p.Estado <> N'cancelado'
GROUP BY YEAR(p.Fecha);
GO

-- Ganancias: SOLO deben consultarse si el usuario tiene el permiso 'ganancias' (el dueño).
-- Ganancia = ventas netas (sin IVA, con descuentos) - costo de lo vendido. No incluye envío.
CREATE OR ALTER VIEW dbo.vw_LineasGanancia AS
SELECT p.IdPedido, p.Fecha, p.Estado, d.IdProducto, pr.Nombre AS Producto, d.Cantidad,
       CAST(d.PrecioNetoUnitario * d.Cantidad
            * CASE WHEN p.Subtotal = 0 THEN 1 ELSE (p.Subtotal - p.Descuento) / p.Subtotal END AS DECIMAL(14,2)) AS VentaNeta,
       CAST(d.CostoUnitario * d.Cantidad AS DECIMAL(14,2)) AS Costo
FROM dbo.DetallePedido d
JOIN dbo.Pedidos p    ON p.IdPedido = d.IdPedido
JOIN dbo.Productos pr ON pr.IdProducto = d.IdProducto
WHERE p.Estado <> N'cancelado';
GO

CREATE OR ALTER VIEW dbo.vw_GananciaDiaria AS
SELECT CAST(Fecha AS DATE) AS Periodo, COUNT(DISTINCT IdPedido) AS Pedidos,
       SUM(VentaNeta) AS VentaNeta, SUM(Costo) AS Costo, SUM(VentaNeta) - SUM(Costo) AS Ganancia
FROM dbo.vw_LineasGanancia
GROUP BY CAST(Fecha AS DATE);
GO

CREATE OR ALTER VIEW dbo.vw_GananciaSemanal AS
SELECT DATEADD(DAY, -(DATEDIFF(DAY, '19000101', f.D) % 7), f.D) AS InicioSemana, COUNT(DISTINCT l.IdPedido) AS Pedidos,
       SUM(l.VentaNeta) AS VentaNeta, SUM(l.Costo) AS Costo, SUM(l.VentaNeta) - SUM(l.Costo) AS Ganancia
FROM dbo.vw_LineasGanancia l
CROSS APPLY (SELECT CAST(l.Fecha AS DATE) AS D) f
GROUP BY DATEADD(DAY, -(DATEDIFF(DAY, '19000101', f.D) % 7), f.D);
GO

CREATE OR ALTER VIEW dbo.vw_GananciaMensual AS
SELECT DATEFROMPARTS(YEAR(Fecha), MONTH(Fecha), 1) AS Mes, COUNT(DISTINCT IdPedido) AS Pedidos,
       SUM(VentaNeta) AS VentaNeta, SUM(Costo) AS Costo, SUM(VentaNeta) - SUM(Costo) AS Ganancia
FROM dbo.vw_LineasGanancia
GROUP BY DATEFROMPARTS(YEAR(Fecha), MONTH(Fecha), 1);
GO

CREATE OR ALTER VIEW dbo.vw_GananciaAnual AS
SELECT YEAR(Fecha) AS Anio, COUNT(DISTINCT IdPedido) AS Pedidos,
       SUM(VentaNeta) AS VentaNeta, SUM(Costo) AS Costo, SUM(VentaNeta) - SUM(Costo) AS Ganancia
FROM dbo.vw_LineasGanancia
GROUP BY YEAR(Fecha);
GO

CREATE OR ALTER VIEW dbo.vw_GananciaPorProducto AS
SELECT IdProducto, Producto, SUM(Cantidad) AS Unidades, SUM(VentaNeta) AS VentaNeta, SUM(Costo) AS Costo,
       SUM(VentaNeta) - SUM(Costo) AS Ganancia,
       CASE WHEN SUM(VentaNeta) = 0 THEN NULL ELSE CAST((SUM(VentaNeta) - SUM(Costo)) * 100.0 / SUM(VentaNeta) AS DECIMAL(6,1)) END AS MargenPct
FROM dbo.vw_LineasGanancia
GROUP BY IdProducto, Producto;
GO

/* =====================================================================
   6. PROCEDIMIENTOS ALMACENADOS
   ===================================================================== */

-- Alta de empleado: genera la sal y guarda solo el hash de la clave.
-- Solo el dueño puede crear a otro dueño (@RolSolicitante; en la carga inicial se usa el valor por defecto).
CREATE OR ALTER PROCEDURE dbo.usp_CrearEmpleado
    @Usuario        NVARCHAR(30),
    @Nombre         NVARCHAR(100),
    @Rol            NVARCHAR(30),
    @Clave          NVARCHAR(100),
    @RolSolicitante NVARCHAR(30) = N'dueno'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdRol INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = @Rol);
    IF @IdRol IS NULL THROW 50020, N'El rol no existe.', 1;
    IF LEN(@Clave) < 4 THROW 50021, N'La clave debe tener al menos 4 caracteres.', 1;
    IF @Rol = N'dueno' AND @RolSolicitante <> N'dueno' THROW 50023, N'Solo el dueño puede crear a otro dueño.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Empleados WHERE Usuario = @Usuario) THROW 50025, N'Ese usuario ya existe.', 1;

    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
    INSERT dbo.Empleados (Usuario, NombreCompleto, IdRol, ClaveSalt, ClaveHash)
    VALUES (@Usuario, @Nombre, @IdRol, @Salt, HASHBYTES('SHA2_256', @Salt + CONVERT(VARBINARY(256), @Clave)));
    SELECT SCOPE_IDENTITY() AS IdEmpleado;
END
GO

-- Modificar empleado. @Clave NULL o vacía = no cambia la clave.
CREATE OR ALTER PROCEDURE dbo.usp_ActualizarEmpleado
    @IdEmpleado     INT,
    @Usuario        NVARCHAR(30),
    @Nombre         NVARCHAR(100),
    @Rol            NVARCHAR(30),
    @Clave          NVARCHAR(100) = NULL,
    @RolSolicitante NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @RolActual NVARCHAR(30) =
        (SELECT r.Nombre FROM dbo.Empleados e JOIN dbo.Roles r ON r.IdRol = e.IdRol WHERE e.IdEmpleado = @IdEmpleado);
    IF @RolActual IS NULL THROW 50022, N'El empleado no existe.', 1;
    DECLARE @IdRol INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = @Rol);
    IF @IdRol IS NULL THROW 50020, N'El rol no existe.', 1;
    IF (@RolActual = N'dueno' OR @Rol = N'dueno') AND @RolSolicitante <> N'dueno'
        THROW 50023, N'Solo el dueño puede modificar o crear a otro dueño.', 1;
    IF @RolActual = N'dueno' AND @Rol <> N'dueno'
       AND NOT EXISTS (SELECT 1 FROM dbo.Empleados e JOIN dbo.Roles r ON r.IdRol = e.IdRol
                       WHERE r.Nombre = N'dueno' AND e.IdEmpleado <> @IdEmpleado AND e.Activo = 1)
        THROW 50024, N'Tiene que haber al menos un dueño.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Empleados WHERE Usuario = @Usuario AND IdEmpleado <> @IdEmpleado)
        THROW 50025, N'Ese usuario ya existe.', 1;
    IF @Clave IS NOT NULL AND LEN(@Clave) > 0 AND LEN(@Clave) < 4
        THROW 50021, N'La clave debe tener al menos 4 caracteres.', 1;

    UPDATE dbo.Empleados SET Usuario = @Usuario, NombreCompleto = @Nombre, IdRol = @IdRol WHERE IdEmpleado = @IdEmpleado;

    IF @Clave IS NOT NULL AND LEN(@Clave) > 0
    BEGIN
        DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
        UPDATE dbo.Empleados
        SET ClaveSalt = @Salt, ClaveHash = HASHBYTES('SHA2_256', @Salt + CONVERT(VARBINARY(256), @Clave))
        WHERE IdEmpleado = @IdEmpleado;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_EliminarEmpleado
    @IdEmpleado     INT,
    @IdSolicitante  INT,
    @RolSolicitante NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @RolActual NVARCHAR(30) =
        (SELECT r.Nombre FROM dbo.Empleados e JOIN dbo.Roles r ON r.IdRol = e.IdRol WHERE e.IdEmpleado = @IdEmpleado);
    IF @RolActual IS NULL THROW 50022, N'El empleado no existe.', 1;
    IF @IdEmpleado = @IdSolicitante THROW 50026, N'No podés borrar tu propio usuario.', 1;
    IF @RolActual = N'dueno' AND @RolSolicitante <> N'dueno' THROW 50023, N'Solo el dueño puede borrar al dueño.', 1;
    IF @RolActual = N'dueno'
       AND NOT EXISTS (SELECT 1 FROM dbo.Empleados e JOIN dbo.Roles r ON r.IdRol = e.IdRol
                       WHERE r.Nombre = N'dueno' AND e.IdEmpleado <> @IdEmpleado AND e.Activo = 1)
        THROW 50024, N'Tiene que haber al menos un dueño.', 1;
    DELETE FROM dbo.Empleados WHERE IdEmpleado = @IdEmpleado;
END
GO

-- Login: devuelve una fila si usuario y clave son correctos (vacío si no).
CREATE OR ALTER PROCEDURE dbo.usp_LoginEmpleado
    @Usuario NVARCHAR(30),
    @Clave   NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.IdEmpleado, e.Usuario, e.NombreCompleto, r.Nombre AS Rol
    FROM dbo.Empleados e
    JOIN dbo.Roles r ON r.IdRol = e.IdRol
    WHERE e.Usuario = @Usuario
      AND e.Activo = 1
      AND e.ClaveHash = HASHBYTES('SHA2_256', e.ClaveSalt + CONVERT(VARBINARY(256), @Clave));
END
GO

-- Registrar un pedido completo: valida, descuenta stock y calcula totales en una sola transacción.
-- @ItemsJson: [{"idProducto":1,"idVersion":4,"idColor":null,"cantidad":2}, ...]
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPedido
    @Nombre    NVARCHAR(100),
    @Email     NVARCHAR(150),
    @Retiro    BIT,
    @Direccion NVARCHAR(200) = NULL,
    @ItemsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EnvioGratis DECIMAL(14,2) = (SELECT Valor FROM dbo.Parametros WHERE Clave = N'ENVIO_GRATIS_DESDE');
    DECLARE @CostoEnvio DECIMAL(14,2) = (SELECT Valor FROM dbo.Parametros WHERE Clave = N'COSTO_ENVIO');
    DECLARE @IvaEnvio DECIMAL(14,2) = (SELECT Valor FROM dbo.Parametros WHERE Clave = N'IVA_GENERAL');

    DECLARE @Items TABLE (IdProducto INT NULL, IdVersion INT NULL, IdColor INT NULL, Cantidad INT NULL);
    INSERT @Items (IdProducto, IdVersion, IdColor, Cantidad)
    SELECT IdProducto, IdVersion, IdColor, Cantidad
    FROM OPENJSON(@ItemsJson) WITH (
        IdProducto INT '$.idProducto',
        IdVersion  INT '$.idVersion',
        IdColor    INT '$.idColor',
        Cantidad   INT '$.cantidad');

    -- Validaciones
    IF NOT EXISTS (SELECT 1 FROM @Items) THROW 50001, N'El pedido no tiene productos.', 1;
    IF EXISTS (SELECT 1 FROM @Items WHERE IdProducto IS NULL OR Cantidad IS NULL OR Cantidad <= 0)
        THROW 50002, N'Hay productos sin id o con cantidad inválida.', 1;
    IF @Retiro = 0 AND (@Direccion IS NULL OR LTRIM(RTRIM(@Direccion)) = N'')
        THROW 50003, N'Falta la dirección de entrega.', 1;
    IF EXISTS (SELECT 1 FROM @Items i LEFT JOIN dbo.Productos p ON p.IdProducto = i.IdProducto
               WHERE p.IdProducto IS NULL OR p.Activo = 0)
        THROW 50004, N'Hay productos que no existen o no están disponibles.', 1;
    IF EXISTS (SELECT 1 FROM @Items i
               WHERE EXISTS (SELECT 1 FROM dbo.ProductoVersiones pv WHERE pv.IdProducto = i.IdProducto)
                 AND (i.IdVersion IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.ProductoVersiones pv
                                                         WHERE pv.IdProducto = i.IdProducto AND pv.IdVersion = i.IdVersion)))
        THROW 50005, N'Falta elegir una versión válida para algún producto.', 1;
    IF EXISTS (SELECT 1 FROM @Items i
               WHERE EXISTS (SELECT 1 FROM dbo.ProductoColores pc WHERE pc.IdProducto = i.IdProducto)
                 AND (i.IdColor IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.ProductoColores pc
                                                       WHERE pc.IdProducto = i.IdProducto AND pc.IdColor = i.IdColor)))
        THROW 50006, N'Falta elegir un color válido para algún producto.', 1;

    DECLARE @IdPedido INT;

    BEGIN TRANSACTION;

        -- Descuento de stock: atómico y sin ventas por encima del stock disponible.
        DECLARE @Stock TABLE (IdProducto INT PRIMARY KEY, Cant INT NOT NULL);
        INSERT @Stock (IdProducto, Cant)
        SELECT IdProducto, SUM(Cantidad) FROM @Items GROUP BY IdProducto;

        UPDATE p SET p.Stock = p.Stock - s.Cant
        FROM dbo.Productos p
        JOIN @Stock s ON s.IdProducto = p.IdProducto
        WHERE p.Stock >= s.Cant;
        DECLARE @Filas INT = @@ROWCOUNT;
        IF @Filas <> (SELECT COUNT(*) FROM @Stock)
            THROW 50008, N'No hay stock suficiente para completar el pedido.', 1;

        -- Líneas con el precio y el costo al momento de la compra
        DECLARE @Lineas TABLE (IdProducto INT, IdVersion INT, IdColor INT, Cantidad INT,
                               NetoUnit DECIMAL(14,4), IvaPct DECIMAL(5,2), CostoUnit DECIMAL(14,4));
        INSERT @Lineas (IdProducto, IdVersion, IdColor, Cantidad, NetoUnit, IvaPct, CostoUnit)
        SELECT i.IdProducto, i.IdVersion, i.IdColor, i.Cantidad,
               CAST(p.PrecioNeto * (1 - p.DescuentoPorcentaje / 100.0) AS DECIMAL(14,4)),
               p.IvaPorcentaje,
               CAST(p.CostoNeto AS DECIMAL(14,4))
        FROM @Items i
        JOIN dbo.Productos p ON p.IdProducto = i.IdProducto;

        -- Totales
        DECLARE @Sub DECIMAL(14,2)       = (SELECT SUM(NetoUnit * (1 + IvaPct / 100.0) * Cantidad) FROM @Lineas);
        DECLARE @NetoItems DECIMAL(14,4) = (SELECT SUM(NetoUnit * Cantidad) FROM @Lineas);
        DECLARE @Desc DECIMAL(14,2)      = 0;
        DECLARE @Envio DECIMAL(14,2)     = CASE WHEN @Retiro = 1 OR @Sub >= @EnvioGratis THEN 0 ELSE @CostoEnvio END;
        DECLARE @Total DECIMAL(14,2)     = @Sub - @Desc + @Envio;
        DECLARE @Neto DECIMAL(14,2)      = ROUND(@NetoItems * (@Sub - @Desc) / @Sub + @Envio / (1 + @IvaEnvio / 100.0), 2);
        DECLARE @Iva DECIMAL(14,2)       = @Total - @Neto;

        -- Cliente (se crea o se actualiza por email). Comprar NO requiere tener una cuenta.
        DECLARE @IdCliente INT = (SELECT IdCliente FROM dbo.Clientes WHERE Email = @Email);
        IF @IdCliente IS NULL
        BEGIN
            INSERT dbo.Clientes (Nombre, Email) VALUES (@Nombre, @Email);
            SET @IdCliente = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE dbo.Clientes SET Nombre = @Nombre WHERE IdCliente = @IdCliente;

        INSERT dbo.Pedidos (IdCliente, Retiro, DireccionEntrega, Subtotal, Descuento, Envio, Neto, Iva, Total)
        VALUES (@IdCliente, @Retiro, CASE WHEN @Retiro = 1 THEN NULL ELSE @Direccion END,
                @Sub, @Desc, @Envio, @Neto, @Iva, @Total);
        SET @IdPedido = SCOPE_IDENTITY();

        INSERT dbo.DetallePedido (IdPedido, IdProducto, IdVersion, IdColor, Cantidad, PrecioNetoUnitario, IvaPorcentaje, CostoUnitario)
        SELECT @IdPedido, IdProducto, IdVersion, IdColor, Cantidad, NetoUnit, IvaPct, CostoUnit
        FROM @Lineas;

    COMMIT TRANSACTION;

    SELECT @IdPedido AS IdPedido, @Total AS Total;
END
GO

-- Cambiar el estado de un pedido. Si se cancela, devuelve el stock.
CREATE OR ALTER PROCEDURE dbo.usp_CambiarEstadoPedido
    @IdPedido INT,
    @Estado   NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
        DECLARE @Actual NVARCHAR(15) = (SELECT Estado FROM dbo.Pedidos WITH (UPDLOCK) WHERE IdPedido = @IdPedido);
        IF @Actual IS NULL THROW 50010, N'El pedido no existe.', 1;
        IF @Actual = N'cancelado' THROW 50011, N'Un pedido cancelado no se puede reactivar.', 1;

        IF @Estado = N'cancelado'
            UPDATE p SET p.Stock = p.Stock + s.Cant
            FROM dbo.Productos p
            JOIN (SELECT IdProducto, SUM(Cantidad) AS Cant FROM dbo.DetallePedido
                  WHERE IdPedido = @IdPedido GROUP BY IdProducto) s ON s.IdProducto = p.IdProducto;

        UPDATE dbo.Pedidos SET Estado = @Estado WHERE IdPedido = @IdPedido;
    COMMIT TRANSACTION;
END
GO

-- Botón de arrepentimiento: guarda la solicitud y la vincula al pedido si el número existe.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarArrepentimiento
    @Nombre       NVARCHAR(100) = NULL,
    @Email        NVARCHAR(150),
    @Monto        DECIMAL(14,2) = NULL,
    @NumeroCompra NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdPedido INT = TRY_CAST(@NumeroCompra AS INT);
    IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE IdPedido = @IdPedido) SET @IdPedido = NULL;

    INSERT dbo.Arrepentimientos (Nombre, Email, MontoReembolso, NumeroCompra, IdPedido)
    VALUES (@Nombre, @Email, @Monto, @NumeroCompra, @IdPedido);
    SELECT SCOPE_IDENTITY() AS IdArrepentimiento;
END
GO

-- Panel: estado de las solicitudes de arrepentimiento y newsletter
CREATE OR ALTER PROCEDURE dbo.usp_CambiarEstadoArrepentimiento
    @IdArrepentimiento INT,
    @Estado            NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Arrepentimientos SET Estado = @Estado WHERE IdArrepentimiento = @IdArrepentimiento;
    IF @@ROWCOUNT = 0 THROW 50050, N'La solicitud no existe.', 1;
END
GO

CREATE OR ALTER VIEW dbo.vw_Arrepentimientos AS
SELECT a.IdArrepentimiento, a.Fecha, a.Nombre, a.Email, a.NumeroCompra, a.MontoReembolso, a.Estado,
       a.IdPedido, p.Estado AS EstadoPedido, p.Total AS TotalPedido
FROM dbo.Arrepentimientos a
LEFT JOIN dbo.Pedidos p ON p.IdPedido = a.IdPedido;
GO

CREATE OR ALTER PROCEDURE dbo.usp_QuitarSuscriptor
    @Email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.Suscriptores WHERE Email = @Email;
END
GO

-- Newsletter
CREATE OR ALTER PROCEDURE dbo.usp_Suscribir
    @Email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Suscriptores WHERE Email = @Email)
        INSERT dbo.Suscriptores (Email) VALUES (@Email);
END
GO

-- ---------- Stock, precios y alta/baja de productos (permisos: stock, precios, altabaja) ----------
CREATE OR ALTER PROCEDURE dbo.usp_AgregarStock
    @IdProducto INT,
    @Cantidad   INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Cantidad IS NULL OR @Cantidad < 1 THROW 50040, N'La cantidad a agregar debe ser de 1 o más.', 1;
    UPDATE dbo.Productos SET Stock = Stock + @Cantidad WHERE IdProducto = @IdProducto;
    IF @@ROWCOUNT = 0 THROW 50041, N'El producto no existe.', 1;
    SELECT IdProducto, Nombre, Stock FROM dbo.Productos WHERE IdProducto = @IdProducto;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ModificarPrecio
    @IdProducto INT,
    @PrecioNeto DECIMAL(12,2),
    @Iva        DECIMAL(5,2),
    @Descuento  DECIMAL(5,2) = 0,
    @CostoNeto  DECIMAL(12,2) = NULL      -- solo lo envía el dueño; NULL = no se toca el costo
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos
    SET PrecioNeto = @PrecioNeto, IvaPorcentaje = @Iva, DescuentoPorcentaje = @Descuento,
        CostoNeto = COALESCE(@CostoNeto, CostoNeto)
    WHERE IdProducto = @IdProducto;
    IF @@ROWCOUNT = 0 THROW 50042, N'El producto no existe.', 1;
    SELECT IdProducto, Nombre, PrecioNeto, PrecioPublico, PrecioFinal FROM dbo.Productos WHERE IdProducto = @IdProducto;
END
GO

-- Baja (0) y alta (1): el producto no se borra, así se conserva el historial de ventas.
CREATE OR ALTER PROCEDURE dbo.usp_CambiarActivoProducto
    @IdProducto INT,
    @Activo     BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos SET Activo = @Activo WHERE IdProducto = @IdProducto;
    IF @@ROWCOUNT = 0 THROW 50043, N'El producto no existe.', 1;
    SELECT IdProducto, Nombre, Activo FROM dbo.Productos WHERE IdProducto = @IdProducto;
END
GO

-- ---------- Cuentas de clientes (opcionales: para comprar NO hace falta tener cuenta) ----------
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarCuenta
    @Nombre NVARCHAR(100),
    @Email  NVARCHAR(150),
    @Clave  NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF LEN(@Clave) < 6 THROW 50030, N'La contraseña debe tener al menos 6 caracteres.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Clientes WHERE Email = @Email AND ClaveHash IS NOT NULL)
        THROW 50031, N'Ya existe una cuenta con ese email.', 1;

    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
    DECLARE @Hash VARBINARY(32) = HASHBYTES('SHA2_256', @Salt + CONVERT(VARBINARY(256), @Clave));

    IF EXISTS (SELECT 1 FROM dbo.Clientes WHERE Email = @Email)
        -- ya había comprado como invitado: se le activa la cuenta y conserva sus pedidos
        UPDATE dbo.Clientes
        SET Nombre = @Nombre, ClaveSalt = @Salt, ClaveHash = @Hash, FechaCuenta = SYSDATETIME()
        WHERE Email = @Email;
    ELSE
        INSERT dbo.Clientes (Nombre, Email, ClaveSalt, ClaveHash, FechaCuenta)
        VALUES (@Nombre, @Email, @Salt, @Hash, SYSDATETIME());

    SELECT IdCliente, Nombre, Email FROM dbo.Clientes WHERE Email = @Email;
END
GO

-- Devuelve una fila si el email y la clave son correctos (vacío si no).
CREATE OR ALTER PROCEDURE dbo.usp_LoginCliente
    @Email NVARCHAR(150),
    @Clave NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.IdCliente, c.Nombre, c.Email
    FROM dbo.Clientes c
    WHERE c.Email = @Email
      AND c.ClaveHash IS NOT NULL
      AND c.ClaveHash = HASHBYTES('SHA2_256', c.ClaveSalt + CONVERT(VARBINARY(256), @Clave));
END
GO

-- "Mis pedidos" de un cliente con cuenta
CREATE OR ALTER PROCEDURE dbo.usp_MisPedidos
    @IdCliente INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.IdPedido, v.Fecha, v.Estado, v.Total, v.Productos
    FROM dbo.vw_ListadoVentas v
    JOIN dbo.Clientes c ON c.Email = v.Email
    WHERE c.IdCliente = @IdCliente
    ORDER BY v.Fecha DESC;
END
GO

/* =====================================================================
   Empleados iniciales (las mismas claves de prueba que usa la página web)
   ===================================================================== */
EXEC dbo.usp_CrearEmpleado N'dueno',     N'Roberto Díaz', N'dueno',          N'dueno123';
EXEC dbo.usp_CrearEmpleado N'gerente',   N'Laura Gómez', N'gerente',        N'gerente123';
EXEC dbo.usp_CrearEmpleado N'admin',     N'Martín Ruiz', N'administrativo', N'admin123';
EXEC dbo.usp_CrearEmpleado N'cajero',    N'Sofía Pérez', N'cajero',         N'cajero123';
EXEC dbo.usp_CrearEmpleado N'repositor', N'Diego Silva', N'repositor',      N'repo123';
GO

/* =====================================================================
   7. PEDIDOS DE EJEMPLO (opcional: borrá este bloque si no los querés)
   Sirven para ver los reportes con datos. Usan el procedimiento real,
   así que también descuentan stock.
   ===================================================================== */
EXEC dbo.usp_RegistrarPedido @Nombre = N'Ana Pérez',   @Email = N'ana@example.com',    @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 1, "idVersion": 1, "idColor": 1, "cantidad": 1}, {"idProducto": 33, "idColor": 7, "cantidad": 1}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Luis Díaz',   @Email = N'luis@example.com',   @Retiro = 0,
     @Direccion = N'Calle Falsa 123, Banfield',
     @ItemsJson = N'[{"idProducto": 7, "idVersion": 5, "idColor": 5, "cantidad": 1}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'María López', @Email = N'maria@example.com',  @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 17, "idColor": 7, "cantidad": 2}, {"idProducto": 34, "idColor": 1, "cantidad": 2}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Pedro Ruiz',  @Email = N'pedro@example.com',  @Retiro = 0,
     @Direccion = N'Av. Hipólito Yrigoyen 8500, Banfield',
     @ItemsJson = N'[{"idProducto": 21, "idVersion": 13, "cantidad": 1}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Carla Gómez', @Email = N'carla@example.com',  @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 25, "idVersion": 9, "idColor": 7, "cantidad": 1}, {"idProducto": 26, "idColor": 1, "cantidad": 2}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Julián Sosa', @Email = N'julian@example.com', @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 19, "idColor": 4, "cantidad": 1}]';

-- Se reparten las fechas de los ejemplos en los últimos meses y se les asignan estados.
UPDATE dbo.Pedidos
SET Fecha  = DATEADD(DAY, -((IdPedido - 999) * 47), SYSDATETIME()),
    Estado = CASE WHEN IdPedido % 3 = 0 THEN N'entregado' WHEN IdPedido % 3 = 1 THEN N'pagado' ELSE N'enviado' END
WHERE IdPedido BETWEEN 1000 AND 1005;
GO

/* =====================================================================
   Consultas de prueba
   ===================================================================== */
-- SELECT * FROM dbo.vw_CatalogoProductos ORDER BY IdProducto;
-- SELECT * FROM dbo.vw_ListadoVentas ORDER BY Fecha DESC;
-- SELECT * FROM dbo.vw_FacturacionMensual ORDER BY Mes DESC;
-- SELECT * FROM dbo.vw_StockBajo;
-- SELECT * FROM dbo.vw_GananciaMensual ORDER BY Mes DESC;      -- solo para el dueño
-- SELECT * FROM dbo.vw_GananciaPorProducto ORDER BY Ganancia DESC;
-- EXEC dbo.usp_RegistrarCuenta N'Ana Pérez', N'ana@example.com', N'secreta1';
-- EXEC dbo.usp_LoginCliente N'ana@example.com', N'secreta1';
-- EXEC dbo.usp_LoginEmpleado N'gerente', N'gerente123';
GO
