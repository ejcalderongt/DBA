-- #EJC20261023_CAREMED_DEMO_REABASTO: cinco reglas con existencias reales.
-- Solo instancia local SQLEXPRESS / TOMWMS_CAREMED_PRD; no modifica stock ni envia tareas.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_CAREMED_PRD' OR CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) <> N'prograx\SQLEXPRESS'
    THROW 50000, 'Instancia o base distinta al entorno local CAREMED autorizado.', 1;

DECLARE @casos TABLE (IdProductoBodega int PRIMARY KEY, IdUbicacion int UNIQUE, Minimo float, Maximo float);
INSERT @casos VALUES (875,9,10,50),(798,12,15,80),(795,24,20,100),(514,39,25,120),(1455,46,30,150);
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM @casos c LEFT JOIN producto_bodega pb ON pb.IdProductoBodega=c.IdProductoBodega AND pb.IdBodega=1 AND pb.activo=1
           LEFT JOIN producto p ON p.IdProducto=pb.IdProducto AND p.IdPropietario=1
           LEFT JOIN bodega_ubicacion u ON u.IdUbicacion=c.IdUbicacion AND u.IdBodega=1 AND u.activo=1 AND u.bloqueada=0 AND u.ubicacion_picking=1
           WHERE pb.IdProductoBodega IS NULL OR p.IdProducto IS NULL OR u.IdUbicacion IS NULL)
    THROW 50001, 'Producto o destino de picking invalido.', 1;
IF EXISTS (SELECT 1 FROM @casos c JOIN stock s ON s.IdBodega=1 AND s.IdUbicacion=c.IdUbicacion WHERE s.cantidad<>0)
    THROW 50002, 'Un destino ya tiene existencias; no se altera stock para preparar la demo.', 1;
IF EXISTS (SELECT 1 FROM @casos c CROSS APPLY
   (SELECT COALESCE(SUM(s.cantidad),0) qty FROM stock s JOIN bodega_ubicacion u ON u.IdBodega=s.IdBodega AND u.IdUbicacion=s.IdUbicacion
    WHERE s.IdBodega=1 AND s.IdProductoBodega=c.IdProductoBodega AND s.IdProductoEstado=1 AND s.IdUnidadMedida=1
      AND u.activo=1 AND u.bloqueada=0 AND u.ubicacion_picking=0 AND s.fecha_vence>GETDATE()) a
   CROSS APPLY (SELECT COALESCE(SUM(sr.cantidad),0) qty FROM stock_res sr
    WHERE sr.IdBodega=1 AND sr.IdProductoBodega=c.IdProductoBodega AND sr.IdProductoEstado=1 AND sr.IdUnidadMedida=1) r
   WHERE a.qty-r.qty<c.Maximo)
    THROW 50003, 'Origen insuficiente despues de reservas.', 1;

DECLARE @base int;
SELECT @base=COALESCE(MAX(IdRellenado),0) FROM producto_rellenado WITH (TABLOCKX,HOLDLOCK);
INSERT producto_rellenado
 (IdRellenado,IdPresentacion,IdProductoEstado,IdUbicacion,IdTipoAccion,Minimo,Maximo,user_agr,fec_agr,user_mod,fec_mod,
  Activo,IdUnidadMedidaBasica,IdBodega,IdProductoBodega,IdUmBasAbastercerCon,IdPresentacionAbastercerCon,
  IdPropietario,NomPresentacionRellenarCon,NomUmBasAbastecerCon,IdOperadorDefecto)
SELECT @base+ROW_NUMBER() OVER(ORDER BY c.IdUbicacion),NULL,1,c.IdUbicacion,1,c.Minimo,c.Maximo,N'1',GETDATE(),N'1',GETDATE(),
       1,1,1,c.IdProductoBodega,1,0,1,N'',N'UN',5
FROM @casos c WHERE NOT EXISTS
 (SELECT 1 FROM producto_rellenado r WHERE r.IdBodega=1 AND r.IdProductoBodega=c.IdProductoBodega AND r.IdUbicacion=c.IdUbicacion AND r.Activo=1);

IF (SELECT COUNT(*) FROM VW_Revision_Producto v JOIN @casos c ON c.IdProductoBodega=v.IdProductoBodega AND c.IdUbicacion=v.IdUbicacion
    WHERE v.IdBodega=1 AND v.Activo=1 AND v.IdUmBasAbastercerCon=1 AND v.Minimo=c.Minimo AND v.Maximo=c.Maximo)<>5
    THROW 50004, 'Las cinco reglas no aparecen correctamente en la vista del monitor.', 1;
COMMIT;

SELECT v.IdRellenado,v.Codigo_Producto,v.Nombre_Producto,v.Ubicacion,v.NombreUmBas,v.Minimo,v.Maximo,
       v.Maximo AS CantidadEsperadaAUbicar,r.IdOperadorDefecto
FROM VW_Revision_Producto v JOIN @casos c ON c.IdProductoBodega=v.IdProductoBodega AND c.IdUbicacion=v.IdUbicacion
JOIN producto_rellenado r ON r.IdRellenado=v.IdRellenado
WHERE v.IdBodega=1 ORDER BY v.IdUbicacion;
