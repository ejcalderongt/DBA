-- #EJC20261023_REFERENCIA_SERIE_NUMERO
-- Reversion manual: impide eliminar la columna si contiene datos.
SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_MHS_DEV' OR CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) <> N'MHS-APP-QA'
    THROW 51000, 'Destino no autorizado.', 1;
BEGIN TRANSACTION;
IF COL_LENGTH(N'dbo.trans_pe_enc', N'Referencia_Serie_Numero') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'IF EXISTS(SELECT 1 FROM dbo.trans_pe_enc WITH (TABLOCKX,HOLDLOCK) WHERE Referencia_Serie_Numero IS NOT NULL) THROW 51003, ''Hay datos: no se permite eliminar la columna.'', 1; ALTER TABLE dbo.trans_pe_enc DROP COLUMN Referencia_Serie_Numero;';
END;
COMMIT;