/* Agrega a una base que YA está cargada las columnas del pago simulado (DNI, país, ciudad, código postal y datos del pago)
   y actualiza el procedimiento usp_RegistrarPedido. No borra datos. Si tu base tiene otro nombre, cambiá la línea USE.
   Del pago solo se guarda la marca y los últimos 4 dígitos: NUNCA el número completo ni el CVC. */
USE EcommerceBanfield;
GO

IF COL_LENGTH('dbo.Pedidos', 'PagoUltimos4') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos ADD
        DireccionCliente NVARCHAR(200) NULL,
        Pais             NVARCHAR(60)  NULL,
        Ciudad           NVARCHAR(80)  NULL,
        CodigoPostal     NVARCHAR(10)  NULL,
        Dni              VARCHAR(12)   NULL,
        PagoMarca        NVARCHAR(20)  NULL,
        PagoUltimos4     CHAR(4)       NULL,
        PagoSimulado     BIT NOT NULL CONSTRAINT DF_Pedidos_PagoSimulado DEFAULT 1;
    ALTER TABLE dbo.Pedidos ADD CONSTRAINT CK_Pedidos_Ultimos4
        CHECK (PagoUltimos4 IS NULL OR PagoUltimos4 LIKE '[0-9][0-9][0-9][0-9]');
END
GO
/* Después ejecutá la parte del procedimiento usp_RegistrarPedido de 01_base_de_datos.sql
   (desde "CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPedido" hasta el primer GO). */
