/* Usuario de SQL Server que usa el servidor web (no uses "sa").
   Cambiá la contraseña antes de ejecutarlo y copiala en el archivo .env (DB_PASSWORD). */
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'banfield_app')
    CREATE LOGIN banfield_app WITH PASSWORD = N'CambiarEstaClave_123!', CHECK_POLICY = ON;
GO
USE EcommerceBanfield;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'banfield_app')
    CREATE USER banfield_app FOR LOGIN banfield_app;
GO
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO banfield_app;
GO
