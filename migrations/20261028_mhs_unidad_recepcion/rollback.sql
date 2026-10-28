-- #EJC20261028_MHS_UNIDAD_RECEPCION: restaurar solo las asignaciones de esta corrección.
SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_MHS_DEV' THROW 50001, 'Script restringido a TOMWMS_MHS_DEV.', 1;
BEGIN TRANSACTION;
DECLARE @id int=(SELECT IdTipoEtiqueta FROM dbo.TIPO_ETIQUETA WHERE Nombre=N'2.12 x 1.22 - MHS_UNIDAD');
UPDATE dbo.PRODUCTO SET IdTipoEtiqueta=CASE WHEN IdProducto=96 THEN 11 ELSE 12 END
WHERE IdTipoEtiqueta=@id AND ((IdProducto=14 AND Codigo='PT169') OR (IdProducto=30 AND Codigo='PT366') OR (IdProducto=96 AND Codigo='PT744'));
-- Se conserva el diseño para no eliminar una etiqueta que otro producto haya asignado.
COMMIT;
