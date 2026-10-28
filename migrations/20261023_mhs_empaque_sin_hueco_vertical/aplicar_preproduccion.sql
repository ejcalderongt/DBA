-- #EJC20261023_EMPAQUE_PREPRODUCCION
-- Seleccionar la base de preproduccion en SSMS y completar su nombre abajo.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @BaseEsperada sysname = N'COMPLETAR_BASE_PREPRODUCCION';
IF DB_NAME() <> @BaseEsperada
    THROW 51000, 'Base distinta a la indicada; revisar destino.', 1;
IF (SELECT COUNT(*) FROM dbo.tipo_etiqueta WHERE IdTipoEtiqueta=14 AND Nombre=N'EMPAQUE MHS') <> 1
    THROW 51001, 'No se encontro la etiqueta 14 EMPAQUE MHS esperada.', 1;
IF OBJECT_ID(N'dbo.EJC20261023_Respaldo_Empaque14',N'U') IS NOT NULL
    THROW 51002, 'Ya existe respaldo de esta migracion; revisar antes de repetir.', 1;
BEGIN TRANSACTION;
SELECT IdTipoEtiqueta, Nombre, codigo_zpl, SYSUTCDATETIME() AS FechaRespaldoUTC
INTO dbo.EJC20261023_Respaldo_Empaque14
FROM dbo.tipo_etiqueta WITH (UPDLOCK,HOLDLOCK) WHERE IdTipoEtiqueta=14;
DECLARE @Zpl nvarchar(max) = N'^XA
^CI28
^MMT
^PW700
^LL0406
^LS0
^FO24,16^A0N,25,16^FH^FDEtiqueta de Empaque^FS
^FO535,20^A0N,18,10^FH^FB140,1,0,R,0^FD{6}^FS
^FO24,54^GB652,2,2^FS
^FO30,50^BQN,2,9^FDLA,{3}^FS
^FO230,74^A0N,34,18^FH^FDLic: {3}^FS
^FO230,122^A0N,26,20^FH^FB440,2,2,L,0^FDOrigen:{0}^FS
^FO230,178^A0N,26,20^FH^FB440,2,2,L,0^FDDestino: {7}^FS
^FO24,260^GB652,2,2^FS
^FO230,150^A0N,26,20^FH^FB440,2,2,L,0^FDDoc: {5}^FS
^FO24,278^A0N,18,8^FH^FB296,1,0,L,0^FDUsuario: {8}^FS
^FO370,278^A0N,18,8^FH^FB306,1,0,L,0^FDImpresion: {9}^FS
^PQ1,0,1,Y
^XZ';
UPDATE dbo.tipo_etiqueta SET codigo_zpl=@Zpl WHERE IdTipoEtiqueta=14 AND Nombre=N'EMPAQUE MHS';
IF @@ROWCOUNT <> 1 THROW 51003, 'Cantidad de etiquetas inesperada.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.tipo_etiqueta WHERE IdTipoEtiqueta=14 AND CONVERT(varbinary(max),codigo_zpl)=CONVERT(varbinary(max),@Zpl))
    THROW 51004, 'No coincide la plantilla guardada.', 1;
COMMIT;
SELECT DB_NAME() AS BaseAplicada,IdTipoEtiqueta,Nombre,codigo_zpl FROM dbo.tipo_etiqueta WHERE IdTipoEtiqueta=14;
-- Reversion manual, en la misma base de preproduccion:
-- UPDATE t SET codigo_zpl=b.codigo_zpl FROM dbo.tipo_etiqueta t
-- JOIN dbo.EJC20261023_Respaldo_Empaque14 b ON b.IdTipoEtiqueta=t.IdTipoEtiqueta
-- WHERE t.IdTipoEtiqueta=14 AND t.Nombre=N'EMPAQUE MHS';