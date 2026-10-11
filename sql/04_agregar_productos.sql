/* Agrega 6 productos nuevos a una base que YA está cargada (no borra nada). Si tu base tiene otro nombre, cambiá la línea USE.
   Los productos quedan DADOS DE BAJA (no se ven en la tienda) con precio 0 y stock 0, hasta que les cargues precio y stock. */
USE EcommerceBanfield;
GO

INSERT dbo.Productos (Nombre, Descripcion, IdCategoria, IdTipo, Marca, PrecioNeto, CostoNeto, IvaPorcentaje, DescuentoPorcentaje, Stock, Emoji, Activo)
SELECT v.Nombre, v.Descripcion, c.IdCategoria, t.IdTipo, v.Marca, 0, 0, 21, 0, 0, v.Emoji, 0
FROM (VALUES
    (N'Smartphone Samsung Galaxy S26 Ultra', N'El tope de gama definitivo: pantalla Dynamic AMOLED 2X de 6.9", procesador de última generación, cámara profesional de 200 MP, 12 GB de RAM y lápiz óptico S Pen integrado.', N'Celulares', N'celular', N'Samsung', N'📱'),
    (N'Smartphone Apple iPhone 18 Pro', N'Innovación pura con chip A20 Pro. Pantalla Super Retina XDR, sistema avanzado de cámaras con grabación de video profesional estabilizado e integración total con IA.', N'Celulares', N'celular', N'Apple', N'📱'),
    (N'Notebook HP Laptop 15.6" Táctil', N'Laptop de alta productividad: Intel Core i5 de 13ª generación, 16 GB de RAM, SSD de 1 TB y pantalla táctil FHD de 15.6". Incluye tecla física de Copilot para asistencia IA.', N'Notebooks', N'notebook', N'HP', N'💻'),
    (N'Notebook Acer Swift Go 16 AI', N'Ultrabook premium para IA: procesador AMD Ryzen AI 9, 32 GB de RAM, SSD de 1 TB y una espectacular pantalla táctil WUXGA de 16" con tasa de refresco de 120 Hz.', N'Notebooks', N'notebook', N'Acer', N'💻'),
    (N'Smartwatch Apple Watch Ultra 3', N'Reloj de aventura extrema en titanio de 49 mm. GPS de doble frecuencia ultra preciso, funciones de conexión satelital, computadora de buceo y batería de hasta 72 horas.', N'Smartwatches', N'smartwatch', N'Apple', N'⌚'),
    (N'Smartwatch Garmin Fenix 8 Pro Microled', N'Reloj deportivo de elite con pantalla MicroLED, caja de titanio de 51 mm y cristal de zafiro. Mapas sin conexión incorporados y conectividad LTE autónoma.', N'Smartwatches', N'smartwatch', N'Garmin', N'⌚')
) v (Nombre, Descripcion, Categoria, Tipo, Marca, Emoji)
JOIN dbo.Categorias c ON c.Nombre = v.Categoria
LEFT JOIN dbo.TiposProducto t ON t.Codigo = v.Tipo
WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos p WHERE p.Nombre = v.Nombre);
GO

/* Para publicarlos: ponerles precio y stock desde el panel (Productos > Precio, + Stock) y darlos de alta. Con SQL:
   DECLARE @Id INT = (SELECT IdProducto FROM dbo.Productos WHERE Nombre = N'Smartphone Apple iPhone 18 Pro');
   EXEC dbo.usp_ModificarPrecio @IdProducto = @Id, @PrecioNeto = 1000000, @Iva = 21, @Descuento = 0, @CostoNeto = 850000;
   EXEC dbo.usp_AgregarStock @IdProducto = @Id, @Cantidad = 10;
   EXEC dbo.usp_CambiarActivoProducto @IdProducto = @Id, @Activo = 1;
*/
