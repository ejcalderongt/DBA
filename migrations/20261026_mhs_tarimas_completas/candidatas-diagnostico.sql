WITH Candidatas AS (
 SELECT DISTINCT UPPER(LTRIM(RTRIM(lic_plate))) LP FROM dbo.stock_res WITH (UPDLOCK,HOLDLOCK)
 WHERE IdBodega=@Bodega AND IdPedido=@Pedido AND IdPicking=@Picking
 AND NULLIF(LTRIM(RTRIM(lic_plate)),'') IS NOT NULL
), Contenido AS (
 SELECT UPPER(LTRIM(RTRIM(s.lic_plate))) LP,'R' Fuente,s.IdRecepcionEnc AS IdRecepcion,s.IdPropietarioBodega,s.IdProductoBodega,s.IdProductoEstado,s.IdPresentacion,s.IdUnidadMedida,ISNULL(s.lote,'') AS lote,ISNULL(s.serial,'') AS serial,ISNULL(s.IdProductoTallaColor,0) AS IdProductoTallaColor,CAST(s.cantidad AS decimal(28,6)) Cantidad
 FROM dbo.stock_rec s WITH (UPDLOCK,HOLDLOCK) JOIN Candidatas c ON c.LP=UPPER(LTRIM(RTRIM(s.lic_plate)))
 WHERE s.IdBodega=@Bodega AND s.activo=1
 UNION ALL
 SELECT UPPER(LTRIM(RTRIM(s.lic_plate))),'S',s.IdRecepcionEnc AS IdRecepcion,s.IdPropietarioBodega,s.IdProductoBodega,s.IdProductoEstado,s.IdPresentacion,s.IdUnidadMedida,ISNULL(s.lote,'') AS lote,ISNULL(s.serial,'') AS serial,ISNULL(s.IdProductoTallaColor,0) AS IdProductoTallaColor,CAST(s.cantidad AS decimal(28,6))
 FROM dbo.stock s WITH (UPDLOCK,HOLDLOCK) JOIN Candidatas c ON c.LP=UPPER(LTRIM(RTRIM(s.lic_plate)))
 WHERE s.IdBodega=@Bodega
 UNION ALL
 SELECT UPPER(LTRIM(RTRIM(s.lic_plate))),'A',s.IdRecepcion AS IdRecepcion,s.IdPropietarioBodega,s.IdProductoBodega,s.IdProductoEstado,s.IdPresentacion,s.IdUnidadMedida,ISNULL(s.lote,'') AS lote,ISNULL(s.serial,'') AS serial,ISNULL(s.IdProductoTallaColor,0) AS IdProductoTallaColor,CAST(s.cantidad AS decimal(28,6))
 FROM dbo.stock_res s WITH (UPDLOCK,HOLDLOCK) JOIN Candidatas c ON c.LP=UPPER(LTRIM(RTRIM(s.lic_plate)))
 WHERE s.IdBodega=@Bodega AND s.IdPedido=@Pedido AND s.IdPicking=@Picking
 UNION ALL
 SELECT UPPER(LTRIM(RTRIM(s.lic_plate))),'P',s.IdRecepcion AS IdRecepcion,s.IdPropietarioBodega,s.IdProductoBodega,s.IdProductoEstado,s.IdPresentacion,s.IdUnidadMedida,ISNULL(s.lote,'') AS lote,ISNULL(s.serial,'') AS serial,ISNULL(s.IdProductoTallaColor,0) AS IdProductoTallaColor,
 CAST(s.cantidad_solicitada * pp.factor AS decimal(28,6))
 FROM dbo.trans_picking_ubic s WITH (UPDLOCK,HOLDLOCK) JOIN Candidatas c ON c.LP=UPPER(LTRIM(RTRIM(s.lic_plate)))
 LEFT JOIN dbo.producto_presentacion pp WITH (HOLDLOCK) ON pp.IdPresentacion=s.IdPresentacion
 WHERE s.IdBodega=@Bodega AND s.IdPedidoEnc=@Pedido AND s.IdPickingEnc=@Picking AND s.activo=1
), Sumas AS (
 SELECT LP,Fuente,IdRecepcion,IdPropietarioBodega,IdProductoBodega,IdProductoEstado,IdPresentacion,IdUnidadMedida,lote,serial,IdProductoTallaColor,SUM(Cantidad) Cantidad FROM Contenido
 GROUP BY LP,Fuente,IdRecepcion,IdPropietarioBodega,IdProductoBodega,IdProductoEstado,IdPresentacion,IdUnidadMedida,lote,serial,IdProductoTallaColor
), Diferencias AS (
 SELECT LP FROM Sumas GROUP BY LP,IdRecepcion,IdPropietarioBodega,IdProductoBodega,IdProductoEstado,IdPresentacion,IdUnidadMedida,lote,serial,IdProductoTallaColor
 HAVING COUNT(DISTINCT Fuente)<>4 OR COUNT(Cantidad)<>4 OR MIN(Cantidad)<=0
 OR MAX(Cantidad)-MIN(Cantidad)>0.000001
), DetalleOriginal AS (
 SELECT UPPER(LTRIM(RTRIM(s.lic_plate))) LP,s.IdRecepcionDet,SUM(CAST(s.cantidad AS decimal(28,6))) Cantidad,
 MAX(CAST(rd.cantidad_recibida * pp.factor AS decimal(28,6))) Recibida,
 MIN(CASE WHEN rd.IdRecepcionEnc=s.IdRecepcionEnc AND rd.IdProductoBodega=s.IdProductoBodega
 AND rd.IdProductoEstado=s.IdProductoEstado AND rd.IdPresentacion=s.IdPresentacion
 AND rd.IdUnidadMedida=s.IdUnidadMedida AND ISNULL(rd.lote,'')=ISNULL(s.lote,'')
 AND ISNULL(rd.IdProductoTallaColor,0)=ISNULL(s.IdProductoTallaColor,0)
 AND UPPER(LTRIM(RTRIM(rd.lic_plate)))=UPPER(LTRIM(RTRIM(s.lic_plate)))
 AND pp.factor>0 THEN 1 ELSE 0 END) Valido
 FROM dbo.stock_rec s WITH (UPDLOCK,HOLDLOCK) JOIN Candidatas c ON c.LP=UPPER(LTRIM(RTRIM(s.lic_plate)))
 LEFT JOIN dbo.trans_re_det rd WITH (HOLDLOCK) ON rd.IdRecepcionDet=s.IdRecepcionDet
 LEFT JOIN dbo.producto_presentacion pp WITH (HOLDLOCK) ON pp.IdPresentacion=rd.IdPresentacion
 WHERE s.IdBodega=@Bodega AND s.activo=1
 GROUP BY UPPER(LTRIM(RTRIM(s.lic_plate))),s.IdRecepcionDet
)
SELECT c.LP FROM Candidatas c
WHERE EXISTS(SELECT 1 FROM Contenido x WHERE x.LP=c.LP AND x.Fuente='R')
AND NOT EXISTS(SELECT 1 FROM Diferencias d WHERE d.LP=c.LP)
AND NOT EXISTS(SELECT 1 FROM DetalleOriginal d WHERE d.LP=c.LP AND
 (d.Valido=0 OR d.Recibida IS NULL OR ABS(d.Cantidad-d.Recibida)>0.000001))
AND NOT EXISTS(SELECT 1 FROM dbo.stock_res z WITH (UPDLOCK,HOLDLOCK)
 WHERE UPPER(LTRIM(RTRIM(z.lic_plate)))=c.LP AND z.cantidad>0
 AND z.IdBodega=@Bodega AND (z.IdPedido<>@Pedido OR z.IdPicking<>@Picking))
ORDER BY c.LP;