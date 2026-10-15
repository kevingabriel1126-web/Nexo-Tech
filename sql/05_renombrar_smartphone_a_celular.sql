/* Cambia "Smartphone" por "Celular" en los nombres y las descripciones de una base que YA está cargada (no borra nada).
   Ejecutalo ANTES de 03_actualizar_descripciones.sql y 04_agregar_productos.sql, que ya usan los nombres nuevos.
   Si tu base tiene otro nombre, cambiá la línea USE. */
USE EcommerceBanfield;
GO

UPDATE dbo.Productos SET Nombre = REPLACE(Nombre, N'Smartphone ', N'Celular ') WHERE Nombre LIKE N'Smartphone %';
UPDATE dbo.Productos SET Descripcion = REPLACE(Descripcion, N'Smartphone', N'Celular') WHERE Descripcion LIKE N'%Smartphone%';
GO

-- Verificación: debería devolver 0 filas
SELECT IdProducto, Nombre FROM dbo.Productos WHERE Nombre LIKE N'%Smartphone%' OR Descripcion LIKE N'%Smartphone%';
GO
