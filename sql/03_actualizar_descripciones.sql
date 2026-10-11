/* Actualiza las descripciones de los 38 productos en una base que YA está cargada (no borra nada).
   Si tu base tiene otro nombre, cambiá la línea USE. */
USE EcommerceBanfield;
GO

UPDATE dbo.Productos SET Descripcion = N'Celular de alta gama con pantalla Dynamic AMOLED 2X de 6,2", procesador Exynos 2400, triple cámara de 50 MP y funciones de Galaxy AI. Batería de 4000 mAh con carga rápida de 25W.' WHERE Nombre = N'Smartphone Samsung Galaxy S24 128GB';
UPDATE dbo.Productos SET Descripcion = N'iPhone con chip A16 Bionic, pantalla Super Retina XDR de 6,1", cámara principal de 48 MP y conector USB-C. Resistente al agua IP68 y carga inalámbrica MagSafe.' WHERE Nombre = N'Smartphone Apple iPhone 15 128GB';
UPDATE dbo.Productos SET Descripcion = N'Celular con pantalla AMOLED de 6,67" a 120 Hz, cámara de 108 MP, batería de 5000 mAh y carga rápida de 33W. Excelente relación precio-calidad.' WHERE Nombre = N'Smartphone Xiaomi Redmi Note 13';
UPDATE dbo.Productos SET Descripcion = N'Smartphone con pantalla pOLED curva de 6,7" a 120 Hz, cámara de 50 MP con OIS, carga TurboPower de 68W y resistencia al agua IP68.' WHERE Nombre = N'Smartphone Motorola Edge 50';

UPDATE dbo.Productos SET Descripcion = N'Notebook ideal para oficina y estudio: Intel Core i5 de 11ª gen, 8 GB de RAM DDR4, SSD de 256 GB y pantalla Full HD de 15,6" antirreflejo.' WHERE Nombre = N'Notebook Lenovo IdeaPad 3 15"';
UPDATE dbo.Productos SET Descripcion = N'Ultrabook con chip Apple M2, 8 GB de RAM unificada, SSD de 256 GB y pantalla Liquid Retina de 13,6". Hasta 18 horas de batería y peso de 1,24 kg.' WHERE Nombre = N'Notebook Apple MacBook Air M2 13"';
UPDATE dbo.Productos SET Descripcion = N'Notebook con procesador AMD Ryzen 5, 16 GB de RAM, SSD de 512 GB y pantalla Full HD de 15,6". Teclado retroiluminado y lector de huellas.' WHERE Nombre = N'Notebook HP Pavilion 15';
UPDATE dbo.Productos SET Descripcion = N'Notebook gamer con Intel Core i7, 16 GB de RAM, SSD de 512 GB y NVIDIA GeForce RTX 4060. Pantalla de 15,6" Full HD a 144 Hz y teclado RGB.' WHERE Nombre = N'Notebook Gamer ASUS TUF F15';

UPDATE dbo.Productos SET Descripcion = N'Tablet con pantalla de 8,7", 4 GB de RAM, 64 GB de almacenamiento ampliable por microSD y batería de 5100 mAh. Ideal para el día a día.' WHERE Nombre = N'Tablet Samsung Galaxy Tab A9';
UPDATE dbo.Productos SET Descripcion = N'iPad con chip A14 Bionic, pantalla Liquid Retina de 10,9", 64 GB de almacenamiento, cámara frontal horizontal de 12 MP y conector USB-C.' WHERE Nombre = N'Tablet Apple iPad 10ma Gen';
UPDATE dbo.Productos SET Descripcion = N'Tablet con pantalla Full HD de 10,6", 4 GB de RAM y 128 GB de almacenamiento. Incluye control parental y modo lectura para los más chicos.' WHERE Nombre = N'Tablet Lenovo Tab M10 Plus';

UPDATE dbo.Productos SET Descripcion = N'Auriculares on-ear inalámbricos con Bluetooth 5.0, sonido JBL Pure Bass, hasta 40 horas de batería y plegables para transportar.' WHERE Nombre = N'Auriculares JBL Tune 510BT';
UPDATE dbo.Productos SET Descripcion = N'Auriculares over-ear con la mejor cancelación de ruido del mercado, 30 horas de batería, audio de alta resolución y conexión multipunto.' WHERE Nombre = N'Auriculares Sony WH-1000XM5';
UPDATE dbo.Productos SET Descripcion = N'Auriculares in-ear con cancelación activa de ruido, modo transparencia adaptativo, audio espacial personalizado y estuche de carga MagSafe con altavoz.' WHERE Nombre = N'Auriculares Apple AirPods Pro 2';
UPDATE dbo.Productos SET Descripcion = N'Parlante Bluetooth portátil con sonido JBL Pro, resistencia al agua y al polvo IP67, hasta 12 horas de batería y modo PartyBoost.' WHERE Nombre = N'Parlante JBL Flip 6';
UPDATE dbo.Productos SET Descripcion = N'Parlante compacto con tecnología Extra Bass, resistencia al agua IP67, hasta 16 horas de batería y correa para colgar.' WHERE Nombre = N'Parlante Sony SRS-XB13';

UPDATE dbo.Productos SET Descripcion = N'Reloj inteligente con pantalla AMOLED, monitoreo de sueño, ritmo cardíaco y oxígeno en sangre. Resistente al agua 5 ATM y hasta 40 horas de batería.' WHERE Nombre = N'Smartwatch Samsung Galaxy Watch 6';
UPDATE dbo.Productos SET Descripcion = N'Reloj con GPS, pantalla Retina, detección de caídas, monitoreo de ritmo cardíaco y más de 20 modos de entrenamiento. Compatible con iPhone.' WHERE Nombre = N'Smartwatch Apple Watch SE';
UPDATE dbo.Productos SET Descripcion = N'Pulsera de actividad con pantalla AMOLED de 1,62", más de 150 modos deportivos, monitoreo de sueño y estrés, y hasta 16 días de batería.' WHERE Nombre = N'Smartband Xiaomi Mi Band 8';

UPDATE dbo.Productos SET Descripcion = N'Televisor 4K Crystal UHD con procesador Crystal 4K, HDR10+, sistema Tizen, 3 puertos HDMI y control remoto SolarCell.' WHERE Nombre = N'Smart TV Samsung 55" 4K';
UPDATE dbo.Productos SET Descripcion = N'Smart TV 4K UHD con procesador α5 Gen6, sistema webOS, HDR10 Pro, modo cine y compatibilidad con Google Assistant y Alexa.' WHERE Nombre = N'Smart TV LG 50" 4K UHD';
UPDATE dbo.Productos SET Descripcion = N'Monitor de 24" con panel IPS Full HD (1920x1080), 75 Hz, 5 ms de respuesta, HDMI y VGA. Ideal para oficina y estudio.' WHERE Nombre = N'Monitor LG 24" Full HD';
UPDATE dbo.Productos SET Descripcion = N'Monitor gamer curvo de 27" con panel VA, resolución Full HD, 165 Hz de refresco, 1 ms de respuesta y tecnología AMD FreeSync Premium.' WHERE Nombre = N'Monitor Gamer Samsung 27" 165Hz';

UPDATE dbo.Productos SET Descripcion = N'Consola con lector de discos, SSD ultrarrápido de 1 TB, soporte para juegos en 4K a 120 fps y control DualSense con retroalimentación háptica.' WHERE Nombre = N'Consola Sony PlayStation 5 Slim';
UPDATE dbo.Productos SET Descripcion = N'Consola más potente de Xbox: 4K real, SSD de 1 TB, Quick Resume, retrocompatibilidad con miles de juegos y lector de discos 4K UHD.' WHERE Nombre = N'Consola Microsoft Xbox Series X';
UPDATE dbo.Productos SET Descripcion = N'Consola híbrida con pantalla OLED de 7", 64 GB de almacenamiento, base con puerto LAN y modo portátil, sobremesa o televisor.' WHERE Nombre = N'Consola Nintendo Switch OLED';
UPDATE dbo.Productos SET Descripcion = N'Control inalámbrico con retroalimentación háptica, gatillos adaptativos, micrófono integrado y batería recargable. Compatible con PS5 y PC.' WHERE Nombre = N'Joystick Sony DualSense PS5';
UPDATE dbo.Productos SET Descripcion = N'Auriculares gamer con sonido envolvente 7.1 virtual, micrófono desmontable con cancelación de ruido, almohadillas de memory foam y conexión USB.' WHERE Nombre = N'Auriculares Gamer HyperX Cloud II';

UPDATE dbo.Productos SET Descripcion = N'Teclado mecánico con switches Red, retroiluminación LED RGB, estructura de metal y teclas anti-ghosting. Disponible en español latinoamericano.' WHERE Nombre = N'Teclado Mecánico Redragon Kumara';
UPDATE dbo.Productos SET Descripcion = N'Mouse gamer con sensor HERO de 25.600 DPI, 11 botones programables, pesos ajustables y retroiluminación RGB LIGHTSYNC.' WHERE Nombre = N'Mouse Logitech G502 Hero';
UPDATE dbo.Productos SET Descripcion = N'Mouse inalámbrico plug-and-play con receptor USB, batería de hasta 12 meses, sensor óptico de 1000 DPI y diseño ambidiestro.' WHERE Nombre = N'Mouse Inalámbrico Logitech M170';
UPDATE dbo.Productos SET Descripcion = N'Webcam Full HD 1080p a 30 fps con dos micrófonos estéreo integrados, corrección automática de luz y soporte universal para trípode.' WHERE Nombre = N'Webcam Logitech C920 HD Pro';
UPDATE dbo.Productos SET Descripcion = N'Cargador de pared con tecnología GaN, 65W de potencia, puerto USB-C con Power Delivery 3.0 y protección contra sobrecarga.' WHERE Nombre = N'Cargador Rápido 65W USB-C';
UPDATE dbo.Productos SET Descripcion = N'Cable de 2 metros con soporte para carga de hasta 100W (5A) y transferencia de datos de hasta 480 Mbps. Trenzado y resistente.' WHERE Nombre = N'Cable USB-C a USB-C 2m';
UPDATE dbo.Productos SET Descripcion = N'Funda protectora de silicona suave con interior antishock, bordes reforzados y recorte preciso para cámaras y puertos.' WHERE Nombre = N'Funda Silicona Universal';
UPDATE dbo.Productos SET Descripcion = N'Soporte de aluminio ergonómico con 6 niveles de altura ajustables, ventilación abierta para mejor refrigeración y hasta 15 kg de carga.' WHERE Nombre = N'Soporte Notebook Aluminio';
UPDATE dbo.Productos SET Descripcion = N'Batería portátil de 20000 mAh con dos salidas USB, carga rápida de 22,5W, indicador LED de carga y protección contra cortocircuitos.' WHERE Nombre = N'Power Bank 20000mAh';
UPDATE dbo.Productos SET Descripcion = N'Hub con salida HDMI 4K, 3 puertos USB 3.0, lector de tarjetas SD/microSD, puerto USB-C de datos y entrada USB-C con Power Delivery de 100W.' WHERE Nombre = N'Hub USB-C 7 en 1';

UPDATE dbo.Productos SET Descripcion = N'El tope de gama definitivo: pantalla Dynamic AMOLED 2X de 6.9", procesador de última generación, cámara profesional de 200 MP, 12 GB de RAM y lápiz óptico S Pen integrado.' WHERE Nombre = N'Smartphone Samsung Galaxy S26 Ultra';
UPDATE dbo.Productos SET Descripcion = N'Innovación pura con chip A20 Pro. Pantalla Super Retina XDR, sistema avanzado de cámaras con grabación de video profesional estabilizado e integración total con IA.' WHERE Nombre = N'Smartphone Apple iPhone 18 Pro';

UPDATE dbo.Productos SET Descripcion = N'Laptop de alta productividad: Intel Core i5 de 13ª generación, 16 GB de RAM, SSD de 1 TB y pantalla táctil FHD de 15.6". Incluye tecla física de Copilot para asistencia IA.' WHERE Nombre = N'Notebook HP Laptop 15.6" Táctil';
UPDATE dbo.Productos SET Descripcion = N'Ultrabook premium para IA: procesador AMD Ryzen AI 9, 32 GB de RAM, SSD de 1 TB y una espectacular pantalla táctil WUXGA de 16" con tasa de refresco de 120 Hz.' WHERE Nombre = N'Notebook Acer Swift Go 16 AI';

UPDATE dbo.Productos SET Descripcion = N'Reloj de aventura extrema en titanio de 49 mm. GPS de doble frecuencia ultra preciso, funciones de conexión satelital, computadora de buceo y batería de hasta 72 horas.' WHERE Nombre = N'Smartwatch Apple Watch Ultra 3';
UPDATE dbo.Productos SET Descripcion = N'Reloj deportivo de elite con pantalla MicroLED, caja de titanio de 51 mm y cristal de zafiro. Mapas sin conexión incorporados y conectividad LTE autónoma.' WHERE Nombre = N'Smartwatch Garmin Fenix 8 Pro Microled';
GO
