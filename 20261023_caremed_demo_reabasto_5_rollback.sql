-- #EJC20261023_CAREMED_DEMO_REABASTO_ROLLBACK
SET XACT_ABORT ON;
IF DB_NAME()<>N'TOMWMS_CAREMED_PRD' OR CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))<>N'prograx\SQLEXPRESS'
 THROW 50000,'Solo entorno local CAREMED.',1;
BEGIN TRAN;
DECLARE @casos TABLE(IdRellenado int,IdProductoBodega int,IdUbicacion int,Minimo float,Maximo float);
INSERT @casos VALUES(5,875,9,10,50),(6,798,12,15,80),(7,795,24,20,100),(8,514,39,25,120),(9,1455,46,30,150);
IF EXISTS(SELECT 1 FROM trans_reabastecimiento_log l JOIN @casos c ON l.IdRellenado=c.IdRellenado WHERE l.IdBodega=1)
 THROW 50001,'Ya existen logs/tareas de estas reglas; cancelar por el flujo normal antes de retirar configuracion.',1;
DELETE r FROM producto_rellenado r JOIN @casos c ON c.IdRellenado=r.IdRellenado AND c.IdProductoBodega=r.IdProductoBodega
 AND c.IdUbicacion=r.IdUbicacion AND c.Minimo=r.Minimo AND c.Maximo=r.Maximo
 WHERE r.IdBodega=1 AND r.IdPropietario=1 AND r.IdOperadorDefecto=5;
COMMIT;
