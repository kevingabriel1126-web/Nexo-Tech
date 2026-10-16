/* Agrega los 7 productos nuevos (S26 Ultra, iPhone 18 Pro, HP táctil, Acer Swift Go 16, Watch Ultra 3, Fenix 8 Pro y Echo Dot 5) a una base que YA está cargada.
   No borra nada y no duplica si lo ejecutás dos veces. Si tu base tiene otro nombre, cambiá la línea USE.
   Los precios son de referencia (con IVA incluido) y el stock es de ejemplo: ajustalos desde el panel. */
USE EcommerceBanfield;
GO

INSERT dbo.Productos (Nombre, Descripcion, IdCategoria, IdTipo, Marca, PrecioNeto, CostoNeto, IvaPorcentaje, DescuentoPorcentaje, Stock, Emoji, Activo, ImagenUrl)
SELECT v.Nombre, v.Descripcion, c.IdCategoria, t.IdTipo, v.Marca, v.Neto, v.Costo, 21, v.Descuento, v.Stock, v.Emoji, v.Activo, v.ImagenUrl
FROM (VALUES
    (N'Celular Samsung Galaxy S26 Ultra', N'El tope de gama definitivo: pantalla Dynamic AMOLED 2X de 6.9", procesador de última generación, cámara profesional de 200 MP, 12 GB de RAM y lápiz óptico S Pen integrado.', N'Celulares', N'celular', N'Samsung', 1450000.00, 1247000.00, 0, 10, N'📱', 1, N'/img/productos/39.webp'),
    (N'Celular Apple iPhone 18 Pro', N'Innovación pura con chip A20 Pro. Pantalla Super Retina XDR, sistema avanzado de cámaras con grabación de video profesional estabilizado e integración total con IA.', N'Celulares', N'celular', N'Apple', 2350000.00, 1974000.00, 0, 10, N'📱', 1, N'/img/productos/40.webp'),
    (N'Notebook HP Laptop 15.6" Táctil', N'Laptop de alta productividad: Intel Core i5 de 13ª generación, 16 GB de RAM, SSD de 1 TB y pantalla táctil FHD de 15.6". Incluye tecla física de Copilot para asistencia IA.', N'Notebooks', N'notebook', N'HP', 1150000.00, 943000.00, 0, 10, N'💻', 1, N'/img/productos/41.webp'),
    (N'Notebook Acer Swift Go 16 AI', N'Ultrabook premium para IA: procesador AMD Ryzen AI 9, 32 GB de RAM, SSD de 1 TB y una espectacular pantalla táctil WUXGA de 16" con tasa de refresco de 120 Hz.', N'Notebooks', N'notebook', N'Acer', 2200000.00, 1760000.00, 0, 10, N'💻', 1, N'/img/productos/42.webp'),
    (N'Smartwatch Apple Watch Ultra 3', N'Reloj de aventura extrema en titanio de 49 mm. GPS de doble frecuencia ultra preciso, funciones de conexión satelital, computadora de buceo y batería de hasta 72 horas.', N'Smartwatches', N'smartwatch', N'Apple', 1600000.00, 1248000.00, 0, 10, N'⌚', 1, N'/img/productos/43.webp'),
    (N'Smartwatch Garmin Fenix 8 Pro Microled', N'Reloj deportivo de elite con pantalla MicroLED, caja de titanio de 51 mm y cristal de zafiro. Mapas sin conexión incorporados y conectividad LTE autónoma.', N'Smartwatches', N'smartwatch', N'Garmin', 3400000.00, 2584000.00, 0, 10, N'⌚', 1, N'/img/productos/44.webp'),
    (N'Asistente Virtual Amazon Echo Dot 5ª Generación', N'Parlante inteligente con Alexa: sonido mejorado con voces más nítidas y graves más potentes (parlante de 44 mm), sensor de temperatura ambiente para armar rutinas, Wi-Fi de doble banda y Bluetooth. Controla con la voz tus dispositivos compatibles del hogar inteligente y tiene botón para apagar los micrófonos.', N'Audio', N'parlante', N'Amazon', 100000.00, 74000.00, 0, 10, N'🔊', 1, N'/img/productos/45.webp')
) v (Nombre, Descripcion, Categoria, Tipo, Marca, Neto, Costo, Descuento, Stock, Emoji, Activo, ImagenUrl)
JOIN dbo.Categorias c ON c.Nombre = v.Categoria
LEFT JOIN dbo.TiposProducto t ON t.Codigo = v.Tipo
WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos p WHERE p.Nombre = v.Nombre);
GO
