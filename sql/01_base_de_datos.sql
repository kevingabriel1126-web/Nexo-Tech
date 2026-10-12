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
    (N'Notebooks'),
    (N'Tablets'),
    (N'Audio'),
    (N'Smartwatches'),
    (N'TV y monitores'),
    (N'Gaming'),
    (N'Accesorios y periféricos');

INSERT dbo.TiposProducto (Codigo, Nombre) VALUES
    (N'celular', N'Celular'),
    (N'notebook', N'Notebook'),
    (N'tablet', N'Tablet'),
    (N'smartwatch', N'Smartwatch o smartband'),
    (N'auriculares', N'Auriculares'),
    (N'parlante', N'Parlante'),
    (N'tv', N'Smart TV'),
    (N'monitor', N'Monitor'),
    (N'consola', N'Consola'),
    (N'joystick', N'Joystick'),
    (N'teclado', N'Teclado'),
    (N'mouse', N'Mouse'),
    (N'webcam', N'Webcam'),
    (N'cargador', N'Cargador'),
    (N'cable', N'Cable'),
    (N'funda', N'Funda'),
    (N'soporte', N'Soporte'),
    (N'powerbank', N'Power bank'),
    (N'hub', N'Hub USB');

-- (el catálogo actual no tiene versiones: se cargan desde el panel con el alta/edición de productos)

-- (el catálogo actual no tiene colores)

INSERT dbo.Parametros (Clave, Valor, Descripcion) VALUES
    (N'IVA_GENERAL',            21,     N'IVA general en %'),
    (N'ENVIO_GRATIS_DESDE',     250000, N'Subtotal desde el cual el envío a domicilio es gratis'),
    (N'COSTO_ENVIO',            9000,   N'Costo del envío a domicilio por debajo del mínimo (valor de demo)'),
    (N'STOCK_BAJO',             5,      N'Stock a partir del cual se considera bajo');

-- Productos (precio neto = precio al público / 1,21). El IdProducto sigue el orden de la lista.
INSERT dbo.Productos (Nombre, Descripcion, IdCategoria, IdTipo, Marca, Anio,
                      PrecioNeto, IvaPorcentaje, DescuentoPorcentaje, Stock, CostoNeto, Emoji, Activo)
SELECT v.Nombre, v.Descripcion, c.IdCategoria, t.IdTipo, v.Marca, v.Anio,
       v.Neto, v.Iva, v.Descuento, v.Stock, v.Costo, v.Emoji, v.Activo
FROM (VALUES
    (1, N'Smartphone Samsung Galaxy S24 128GB', N'Celular de alta gama con pantalla Dynamic AMOLED 2X de 6,2", procesador Exynos 2400, triple cámara de 50 MP y funciones de Galaxy AI. Batería de 4000 mAh con carga rápida de 25W.', N'Celulares', N'celular', N'Samsung', NULL, 1000000.00, 21, 0, 4, 720000.00, N'📱', 1),
    (2, N'Smartphone Apple iPhone 15 128GB', N'iPhone con chip A16 Bionic, pantalla Super Retina XDR de 6,1", cámara principal de 48 MP y conector USB-C. Resistente al agua IP68 y carga inalámbrica MagSafe.', N'Celulares', N'celular', N'Apple', NULL, 1400000.00, 21, 0, 11, 1190000.00, N'📱', 1),
    (3, N'Smartphone Xiaomi Redmi Note 13', N'Celular con pantalla AMOLED de 6,67" a 120 Hz, cámara de 108 MP, batería de 5000 mAh y carga rápida de 33W. Excelente relación precio-calidad.', N'Celulares', N'celular', N'Xiaomi', NULL, 400000.00, 21, 10, 18, 332000.00, N'📱', 1),
    (4, N'Smartphone Motorola Edge 50', N'Smartphone con pantalla pOLED curva de 6,7" a 120 Hz, cámara de 50 MP con OIS, carga TurboPower de 68W y resistencia al agua IP68.', N'Celulares', N'celular', N'Motorola', NULL, 750000.00, 21, 0, 25, 607500.00, N'📱', 1),
    (5, N'Notebook Lenovo IdeaPad 3 15"', N'Notebook ideal para oficina y estudio: Intel Core i5 de 11ª gen, 8 GB de RAM DDR4, SSD de 256 GB y pantalla Full HD de 15,6" antirreflejo.', N'Notebooks', N'notebook', N'Lenovo', NULL, 850000.00, 21, 0, 3, 671500.00, N'💻', 1),
    (6, N'Notebook Apple MacBook Air M2 13"', N'Ultrabook con chip Apple M2, 8 GB de RAM unificada, SSD de 256 GB y pantalla Liquid Retina de 13,6". Hasta 18 horas de batería y peso de 1,24 kg.', N'Notebooks', N'notebook', N'Apple', NULL, 1900000.00, 21, 0, 16, 1463000.00, N'💻', 1),
    (7, N'Notebook HP Pavilion 15', N'Notebook con procesador AMD Ryzen 5, 16 GB de RAM, SSD de 512 GB y pantalla Full HD de 15,6". Teclado retroiluminado y lector de huellas.', N'Notebooks', N'notebook', N'HP', NULL, 1100000.00, 21, 5, 23, 825000.00, N'💻', 1),
    (8, N'Notebook Gamer ASUS TUF F15', N'Notebook gamer con Intel Core i7, 16 GB de RAM, SSD de 512 GB y NVIDIA GeForce RTX 4060. Pantalla de 15,6" Full HD a 144 Hz y teclado RGB.', N'Notebooks', N'notebook', N'ASUS', NULL, 1800000.00, 21, 0, 7, 1314000.00, N'💻', 1),
    (9, N'Tablet Samsung Galaxy Tab A9', N'Tablet con pantalla de 8,7", 4 GB de RAM, 64 GB de almacenamiento ampliable por microSD y batería de 5100 mAh. Ideal para el día a día.', N'Tablets', N'tablet', N'Samsung', NULL, 350000.00, 21, 0, 14, 301000.00, N'📲', 1),
    (10, N'Tablet Apple iPad 10ma Gen', N'iPad con chip A14 Bionic, pantalla Liquid Retina de 10,9", 64 GB de almacenamiento, cámara frontal horizontal de 12 MP y conector USB-C.', N'Tablets', N'tablet', N'Apple', NULL, 700000.00, 21, 0, 21, 588000.00, N'📲', 1),
    (11, N'Tablet Lenovo Tab M10 Plus', N'Tablet con pantalla Full HD de 10,6", 4 GB de RAM y 128 GB de almacenamiento. Incluye control parental y modo lectura para los más chicos.', N'Tablets', N'tablet', N'Lenovo', NULL, 280000.00, 21, 15, 5, 229600.00, N'📲', 1),
    (12, N'Auriculares JBL Tune 510BT', N'Auriculares on-ear inalámbricos con Bluetooth 5.0, sonido JBL Pure Bass, hasta 40 horas de batería y plegables para transportar.', N'Audio', N'auriculares', N'JBL', NULL, 90000.00, 21, 0, 12, 72000.00, N'🎧', 1),
    (13, N'Auriculares Sony WH-1000XM5', N'Auriculares over-ear con la mejor cancelación de ruido del mercado, 30 horas de batería, audio de alta resolución y conexión multipunto.', N'Audio', N'auriculares', N'Sony', NULL, 550000.00, 21, 0, 19, 429000.00, N'🎧', 1),
    (14, N'Auriculares Apple AirPods Pro 2', N'Auriculares in-ear con cancelación activa de ruido, modo transparencia adaptativo, audio espacial personalizado y estuche de carga MagSafe con altavoz.', N'Audio', N'auriculares', N'Apple', NULL, 380000.00, 21, 0, 3, 288800.00, N'🎧', 1),
    (15, N'Parlante JBL Flip 6', N'Parlante Bluetooth portátil con sonido JBL Pro, resistencia al agua y al polvo IP67, hasta 12 horas de batería y modo PartyBoost.', N'Audio', N'parlante', N'JBL', NULL, 150000.00, 21, 10, 10, 111000.00, N'🔊', 1),
    (16, N'Parlante Sony SRS-XB13', N'Parlante compacto con tecnología Extra Bass, resistencia al agua IP67, hasta 16 horas de batería y correa para colgar.', N'Audio', N'parlante', N'Sony', NULL, 95000.00, 21, 0, 17, 68400.00, N'🔊', 1),
    (17, N'Smartwatch Samsung Galaxy Watch 6', N'Reloj inteligente con pantalla AMOLED, monitoreo de sueño, ritmo cardíaco y oxígeno en sangre. Resistente al agua 5 ATM y hasta 40 horas de batería.', N'Smartwatches', N'smartwatch', N'Samsung', NULL, 350000.00, 21, 0, 24, 297500.00, N'⌚', 1),
    (18, N'Smartwatch Apple Watch SE', N'Reloj con GPS, pantalla Retina, detección de caídas, monitoreo de ritmo cardíaco y más de 20 modos de entrenamiento. Compatible con iPhone.', N'Smartwatches', N'smartwatch', N'Apple', NULL, 450000.00, 21, 0, 8, 373500.00, N'⌚', 1),
    (19, N'Smartband Xiaomi Mi Band 8', N'Pulsera de actividad con pantalla AMOLED de 1,62", más de 150 modos deportivos, monitoreo de sueño y estrés, y hasta 16 días de batería.', N'Smartwatches', N'smartwatch', N'Xiaomi', NULL, 60000.00, 21, 0, 15, 48600.00, N'⌚', 1),
    (20, N'Smart TV Samsung 55" 4K', N'Televisor 4K Crystal UHD con procesador Crystal 4K, HDR10+, sistema Tizen, 3 puertos HDMI y control remoto SolarCell.', N'TV y monitores', N'tv', N'Samsung', NULL, 1100000.00, 21, 0, 22, 869000.00, N'📺', 1),
    (21, N'Smart TV LG 50" 4K UHD', N'Smart TV 4K UHD con procesador α5 Gen6, sistema webOS, HDR10 Pro, modo cine y compatibilidad con Google Assistant y Alexa.', N'TV y monitores', N'tv', N'LG', NULL, 950000.00, 21, 8, 6, 731500.00, N'📺', 1),
    (22, N'Monitor LG 24" Full HD', N'Monitor de 24" con panel IPS Full HD (1920x1080), 75 Hz, 5 ms de respuesta, HDMI y VGA. Ideal para oficina y estudio.', N'TV y monitores', N'monitor', N'LG', NULL, 250000.00, 21, 0, 13, 187500.00, N'🖥️', 1),
    (23, N'Monitor Gamer Samsung 27" 165Hz', N'Monitor gamer curvo de 27" con panel VA, resolución Full HD, 165 Hz de refresco, 1 ms de respuesta y tecnología AMD FreeSync Premium.', N'TV y monitores', N'monitor', N'Samsung', NULL, 480000.00, 21, 0, 3, 350400.00, N'🖥️', 1),
    (24, N'Consola Sony PlayStation 5 Slim', N'Consola con lector de discos, SSD ultrarrápido de 1 TB, soporte para juegos en 4K a 120 fps y control DualSense con retroalimentación háptica.', N'Gaming', N'consola', N'Sony', NULL, 1300000.00, 21, 0, 18, 1118000.00, N'🎮', 1),
    (25, N'Consola Microsoft Xbox Series X', N'Consola más potente de Xbox: 4K real, SSD de 1 TB, Quick Resume, retrocompatibilidad con miles de juegos y lector de discos 4K UHD.', N'Gaming', N'consola', N'Microsoft', NULL, 1250000.00, 21, 0, 4, 1050000.00, N'🎮', 1),
    (26, N'Consola Nintendo Switch OLED', N'Consola híbrida con pantalla OLED de 7", 64 GB de almacenamiento, base con puerto LAN y modo portátil, sobremesa o televisor.', N'Gaming', N'consola', N'Nintendo', NULL, 750000.00, 21, 0, 11, 615000.00, N'🎮', 1),
    (27, N'Joystick Sony DualSense PS5', N'Control inalámbrico con retroalimentación háptica, gatillos adaptativos, micrófono integrado y batería recargable. Compatible con PS5 y PC.', N'Gaming', N'joystick', N'Sony', NULL, 130000.00, 21, 0, 20, 104000.00, N'🕹️', 1),
    (28, N'Auriculares Gamer HyperX Cloud II', N'Auriculares gamer con sonido envolvente 7.1 virtual, micrófono desmontable con cancelación de ruido, almohadillas de memory foam y conexión USB.', N'Gaming', N'auriculares', N'HyperX', NULL, 180000.00, 21, 10, 5, 140400.00, N'🎧', 1),
    (29, N'Teclado Mecánico Redragon Kumara', N'Teclado mecánico con switches Red, retroiluminación LED RGB, estructura de metal y teclas anti-ghosting. Disponible en español latinoamericano.', N'Accesorios y periféricos', N'teclado', N'Redragon', NULL, 85000.00, 21, 0, 9, 64600.00, N'⌨️', 1),
    (30, N'Mouse Logitech G502 Hero', N'Mouse gamer con sensor HERO de 25.600 DPI, 11 botones programables, pesos ajustables y retroiluminación RGB LIGHTSYNC.', N'Accesorios y periféricos', N'mouse', N'Logitech', NULL, 95000.00, 21, 0, 16, 70300.00, N'🖱️', 1),
    (31, N'Mouse Inalámbrico Logitech M170', N'Mouse inalámbrico plug-and-play con receptor USB, batería de hasta 12 meses, sensor óptico de 1000 DPI y diseño ambidiestro.', N'Accesorios y periféricos', N'mouse', N'Logitech', NULL, 25000.00, 21, 0, 23, 18000.00, N'🖱️', 1),
    (32, N'Webcam Logitech C920 HD Pro', N'Webcam Full HD 1080p a 30 fps con dos micrófonos estéreo integrados, corrección automática de luz y soporte universal para trípode.', N'Accesorios y periféricos', N'webcam', N'Logitech', NULL, 120000.00, 21, 0, 7, 102000.00, N'📷', 1),
    (33, N'Cargador Rápido 65W USB-C', N'Cargador de pared con tecnología GaN, 65W de potencia, puerto USB-C con Power Delivery 3.0 y protección contra sobrecarga.', N'Accesorios y periféricos', N'cargador', NULL, NULL, 35000.00, 21, 0, 14, 29050.00, N'🔌', 1),
    (34, N'Cable USB-C a USB-C 2m', N'Cable de 2 metros con soporte para carga de hasta 100W (5A) y transferencia de datos de hasta 480 Mbps. Trenzado y resistente.', N'Accesorios y periféricos', N'cable', NULL, NULL, 12000.00, 21, 0, 21, 9720.00, N'🔗', 1),
    (35, N'Funda Silicona Universal', N'Funda protectora de silicona suave con interior antishock, bordes reforzados y recorte preciso para cámaras y puertos.', N'Accesorios y periféricos', N'funda', NULL, NULL, 8000.00, 21, 0, 3, 6320.00, N'🛡️', 1),
    (36, N'Soporte Notebook Aluminio', N'Soporte de aluminio ergonómico con 6 niveles de altura ajustables, ventilación abierta para mejor refrigeración y hasta 15 kg de carga.', N'Accesorios y periféricos', N'soporte', NULL, NULL, 28000.00, 21, 0, 10, 21560.00, N'💼', 1),
    (37, N'Power Bank 20000mAh', N'Batería portátil de 20000 mAh con dos salidas USB, carga rápida de 22,5W, indicador LED de carga y protección contra cortocircuitos.', N'Accesorios y periféricos', N'powerbank', NULL, NULL, 55000.00, 21, 5, 17, 41250.00, N'🔋', 1),
    (38, N'Hub USB-C 7 en 1', N'Hub con salida HDMI 4K, 3 puertos USB 3.0, lector de tarjetas SD/microSD, puerto USB-C de datos y entrada USB-C con Power Delivery de 100W.', N'Accesorios y periféricos', N'hub', NULL, NULL, 45000.00, 21, 0, 24, 32850.00, N'🧩', 1),
    (39, N'Smartphone Samsung Galaxy S26 Ultra', N'El tope de gama definitivo: pantalla Dynamic AMOLED 2X de 6.9", procesador de última generación, cámara profesional de 200 MP, 12 GB de RAM y lápiz óptico S Pen integrado.', N'Celulares', N'celular', N'Samsung', NULL, 1450000.00, 21, 0, 10, 1247000.00, N'📱', 1),
    (40, N'Smartphone Apple iPhone 18 Pro', N'Innovación pura con chip A20 Pro. Pantalla Super Retina XDR, sistema avanzado de cámaras con grabación de video profesional estabilizado e integración total con IA.', N'Celulares', N'celular', N'Apple', NULL, 2350000.00, 21, 0, 10, 1974000.00, N'📱', 1),
    (41, N'Notebook HP Laptop 15.6" Táctil', N'Laptop de alta productividad: Intel Core i5 de 13ª generación, 16 GB de RAM, SSD de 1 TB y pantalla táctil FHD de 15.6". Incluye tecla física de Copilot para asistencia IA.', N'Notebooks', N'notebook', N'HP', NULL, 1150000.00, 21, 0, 10, 943000.00, N'💻', 1),
    (42, N'Notebook Acer Swift Go 16 AI', N'Ultrabook premium para IA: procesador AMD Ryzen AI 9, 32 GB de RAM, SSD de 1 TB y una espectacular pantalla táctil WUXGA de 16" con tasa de refresco de 120 Hz.', N'Notebooks', N'notebook', N'Acer', NULL, 2200000.00, 21, 0, 10, 1760000.00, N'💻', 1),
    (43, N'Smartwatch Apple Watch Ultra 3', N'Reloj de aventura extrema en titanio de 49 mm. GPS de doble frecuencia ultra preciso, funciones de conexión satelital, computadora de buceo y batería de hasta 72 horas.', N'Smartwatches', N'smartwatch', N'Apple', NULL, 1600000.00, 21, 0, 10, 1248000.00, N'⌚', 1),
    (44, N'Smartwatch Garmin Fenix 8 Pro Microled', N'Reloj deportivo de elite con pantalla MicroLED, caja de titanio de 51 mm y cristal de zafiro. Mapas sin conexión incorporados y conectividad LTE autónoma.', N'Smartwatches', N'smartwatch', N'Garmin', NULL, 3400000.00, 21, 0, 10, 2584000.00, N'⌚', 1),
    (45, N'Asistente Virtual Amazon Echo Dot 5ª Generación', N'Parlante inteligente con Alexa: sonido mejorado con voces más nítidas y graves más potentes (parlante de 44 mm), sensor de temperatura ambiente para armar rutinas, Wi-Fi de doble banda y Bluetooth. Controla con la voz tus dispositivos compatibles del hogar inteligente y tiene botón para apagar los micrófonos.', N'Audio', N'parlante', N'Amazon', NULL, 100000.00, 21, 0, 10, 74000.00, N'🔊', 1)
) v (Orden, Nombre, Descripcion, Categoria, Tipo, Marca, Anio, Neto, Iva, Descuento, Stock, Costo, Emoji, Activo)
JOIN dbo.Categorias c ON c.Nombre = v.Categoria
LEFT JOIN dbo.TiposProducto t ON t.Codigo = v.Tipo
ORDER BY v.Orden;

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
     @ItemsJson = N'[{"idProducto": 2, "cantidad": 1}, {"idProducto": 34, "cantidad": 2}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Luis Díaz',   @Email = N'luis@example.com',   @Retiro = 0,
     @Direccion = N'Calle Falsa 123, Banfield',
     @ItemsJson = N'[{"idProducto": 6, "cantidad": 1}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'María López', @Email = N'maria@example.com',  @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 31, "cantidad": 1}, {"idProducto": 33, "cantidad": 1}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Pedro Ruiz',  @Email = N'pedro@example.com',  @Retiro = 0,
     @Direccion = N'Av. Hipólito Yrigoyen 8500, Banfield',
     @ItemsJson = N'[{"idProducto": 20, "cantidad": 1}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Carla Gómez', @Email = N'carla@example.com',  @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 24, "cantidad": 1}, {"idProducto": 27, "cantidad": 2}]';
EXEC dbo.usp_RegistrarPedido @Nombre = N'Julián Sosa', @Email = N'julian@example.com', @Retiro = 1,
     @ItemsJson = N'[{"idProducto": 15, "cantidad": 1}]';

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
