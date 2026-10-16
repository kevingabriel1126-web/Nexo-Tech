/* Carga la imagen de cada producto en una base que YA está cargada (no borra nada).
   Los archivos de las imágenes están en public/img/productos/ del repositorio (el nombre del archivo es el IdProducto).
   Si tu base tiene otro nombre, cambiá la línea USE. */
USE EcommerceBanfield;
GO

UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/26.webp' WHERE Nombre = N'Consola Nintendo Switch OLED';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/27.webp' WHERE Nombre = N'Joystick Sony DualSense PS5';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/28.webp' WHERE Nombre = N'Auriculares Gamer HyperX Cloud II';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/29.webp' WHERE Nombre = N'Teclado Mecánico Redragon Kumara';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/30.webp' WHERE Nombre = N'Mouse Logitech G502 Hero';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/31.webp' WHERE Nombre = N'Mouse Inalámbrico Logitech M170';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/32.webp' WHERE Nombre = N'Webcam Logitech C920 HD Pro';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/33.webp' WHERE Nombre = N'Cargador Rápido 65W USB-C';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/34.webp' WHERE Nombre = N'Cable USB-C a USB-C 2m';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/35.webp' WHERE Nombre = N'Funda Silicona Universal';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/36.webp' WHERE Nombre = N'Soporte Notebook Aluminio';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/37.webp' WHERE Nombre = N'Power Bank 20000mAh';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/38.webp' WHERE Nombre = N'Hub USB-C 7 en 1';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/39.webp' WHERE Nombre = N'Celular Samsung Galaxy S26 Ultra';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/40.webp' WHERE Nombre = N'Celular Apple iPhone 18 Pro';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/41.webp' WHERE Nombre = N'Notebook HP Laptop 15.6" Táctil';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/42.webp' WHERE Nombre = N'Notebook Acer Swift Go 16 AI';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/43.webp' WHERE Nombre = N'Smartwatch Apple Watch Ultra 3';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/44.webp' WHERE Nombre = N'Smartwatch Garmin Fenix 8 Pro Microled';
UPDATE dbo.Productos SET ImagenUrl = N'/img/productos/45.webp' WHERE Nombre = N'Asistente Virtual Amazon Echo Dot 5ª Generación';
GO
