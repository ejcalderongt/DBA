-- #EJC20261023_REFERENCIA_SERIE_NUMERO
-- Referencia: TOMWMS_CAREMED_PRD local, dbo.trans_pe_enc: nvarchar(20) NULL, sin DEFAULT.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_MHS_DEV' OR CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) <> N'MHS-APP-QA'
    THROW 51000, 'Destino no autorizado: solo MHS-APP-QA / TOMWMS_MHS_DEV.', 1;
IF OBJECT_ID(N'dbo.trans_pe_enc', N'U') IS NULL
    THROW 51001, 'No existe dbo.trans_pe_enc.', 1;
BEGIN TRANSACTION;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.trans_pe_enc') AND name=N'Referencia_Serie_Numero')
    ALTER TABLE dbo.trans_pe_enc ADD Referencia_Serie_Numero nvarchar(20) NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.trans_pe_enc') AND name=N'Referencia_Serie_Numero' AND system_type_id=231 AND max_length=40 AND is_nullable=1)
    THROW 51002, 'La columna existente tiene una estructura distinta; revisar manualmente.', 1;
COMMIT;
SELECT DB_NAME() base_datos,t.name tabla,c.name columna,TYPE_NAME(c.user_type_id) tipo,c.max_length/2 caracteres,c.is_nullable
FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id
WHERE t.object_id=OBJECT_ID(N'dbo.trans_pe_enc') AND c.name=N'Referencia_Serie_Numero';