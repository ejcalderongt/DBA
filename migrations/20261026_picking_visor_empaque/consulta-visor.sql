-- #EJC20261026_PICKING_VISOR_EMPAQUE
WITH Packing AS (
 SELECT pk.*,
 CAST(pk.IdPedidoEnc AS varchar(20)) + '|' +
 CASE WHEN NULLIF(LTRIM(RTRIM(pk.no_linea)),'') IS NULL THEN 'P|' + CAST(pk.IdPackingEnc AS varchar(20))
 ELSE 'L|' + UPPER(LTRIM(RTRIM(pk.no_linea))) END ClaveLicencia,
 CASE WHEN NULLIF(LTRIM(RTRIM(pk.no_linea)),'') IS NULL THEN '(SIN LICENCIA #' + CAST(pk.IdPackingEnc AS varchar(20)) + ')'
 ELSE UPPER(LTRIM(RTRIM(pk.no_linea))) END LicenciaEmpaque
 FROM dbo.trans_packing_enc pk
 WHERE pk.IdPickingEnc=@Picking AND pk.IdBodega=@Bodega
), Claves AS (
 SELECT CAST(pe.IdPedidoEnc AS varchar(20))+'|L|'+UPPER(LTRIM(RTRIM(le.LicPlate))) ClaveLicencia,
 pe.IdPedidoEnc,UPPER(LTRIM(RTRIM(le.LicPlate))) LicenciaEmpaque
 FROM dbo.trans_licencia_empaque le JOIN dbo.trans_pe_enc pe
 ON le.TipoOrigen='PEDIDO' AND le.IdDocumento=pe.IdPedidoEnc AND le.IdBodega=pe.IdBodega
 WHERE pe.IdPickingEnc=@Picking AND pe.IdBodega=@Bodega
 UNION
 SELECT ClaveLicencia,IdPedidoEnc,LicenciaEmpaque FROM Packing
), Totales AS (
 SELECT ClaveLicencia,COUNT(*) LineasEmpacadas,
 SUM(CASE WHEN ISNULL(Finalizado,0)=1 THEN 1 ELSE 0 END) LineasFinalizadas,
 COUNT(DISTINCT NULLIF(IdOperadorBodega,0)) Operadores,
 MIN(CASE WHEN Fecha_packing>'19000101' THEN Fecha_packing END) PrimeraLineaPacking,
 MAX(CASE WHEN Fecha_packing>'19000101' THEN Fecha_packing END) UltimaLineaPacking
 FROM Packing GROUP BY ClaveLicencia
)
SELECT c.ClaveLicencia,@Bodega IdBodega,@Picking IdPickingEnc,c.IdPedidoEnc,
 ISNULL(pe.Referencia,'') ReferenciaPedido,c.LicenciaEmpaque,le.IdLicenciaEmpaque,
 CASE WHEN le.IdLicenciaEmpaque IS NULL THEN 'HISTORICA / SIN CABECERA'
 WHEN le.EsRecicladaRecepcion=1 THEN 'REUTILIZADA' ELSE 'NUEVA' END OrigenEtiqueta,
 le.EsRecicladaRecepcion,ISNULL(le.Estado,'SIN CABECERA') EstadoLicencia,
 CASE WHEN le.Estado='ANULADA' OR le.Activo=0 THEN 'ANULADA / INACTIVA'
 WHEN ISNULL(t.LineasEmpacadas,0)=0 THEN 'VACIA'
 WHEN t.LineasFinalizadas=t.LineasEmpacadas THEN 'LINEAS FINALIZADAS'
 ELSE 'CON CONTENIDO' END EstadoContenido,
 ISNULL(t.LineasEmpacadas,0) LineasEmpacadas,ISNULL(t.LineasFinalizadas,0) LineasFinalizadas,
 ISNULL(t.Operadores,0) Operadores,
 le.FechaGeneracion,le.user_agr UsuarioGeneracionCodigo,
 COALESCE(NULLIF(LTRIM(RTRIM(ISNULL(ug.nombres,'')+' '+ISNULL(ug.apellidos,''))),''),le.user_agr) UsuarioGeneracion,
 le.FechaPrimeraImpresion,le.FechaUltimaImpresion,le.UsuarioUltimaImpresion UsuarioUltimaImpresionCodigo,
 COALESCE(NULLIF(LTRIM(RTRIM(ISNULL(ui.nombres,'')+' '+ISNULL(ui.apellidos,''))),''),le.UsuarioUltimaImpresion) UsuarioUltimaImpresion,
 le.CantidadImpresiones,le.FechaAsociacion PrimeraAsociacion,
 t.PrimeraLineaPacking,t.UltimaLineaPacking,
 CASE WHEN le.FechaPrimeraImpresion>=le.FechaGeneracion THEN
 CAST(DATEDIFF_BIG(SECOND,le.FechaGeneracion,le.FechaPrimeraImpresion)/60.0 AS decimal(18,2)) END MinGeneracionImpresion,
 CASE WHEN le.FechaAsociacion>=le.FechaGeneracion THEN
 CAST(DATEDIFF_BIG(SECOND,le.FechaGeneracion,le.FechaAsociacion)/60.0 AS decimal(18,2)) END MinGeneracionAsociacion,
 CASE WHEN t.LineasEmpacadas>1 AND t.UltimaLineaPacking>=t.PrimeraLineaPacking THEN
 CAST(DATEDIFF_BIG(SECOND,t.PrimeraLineaPacking,t.UltimaLineaPacking)/60.0 AS decimal(18,2)) END MinEntreRegistrosPacking,
 CASE WHEN le.IdBodega<>@Bodega THEN 'LICENCIA DE OTRA BODEGA'
 WHEN le.TipoOrigen='PEDIDO' AND le.IdDocumento<>c.IdPedidoEnc THEN 'LICENCIA DE OTRO PEDIDO'
 WHEN le.IdLicenciaEmpaque IS NULL THEN 'SIN CABECERA DE LICENCIA'
 WHEN le.FechaPrimeraImpresion<le.FechaGeneracion OR le.FechaAsociacion<le.FechaGeneracion THEN 'REVISAR FECHAS'
 ELSE '' END ObservacionTrazabilidad,
 le.Observacion
FROM Claves c
LEFT JOIN dbo.trans_pe_enc pe ON pe.IdPedidoEnc=c.IdPedidoEnc AND pe.IdBodega=@Bodega
LEFT JOIN dbo.trans_licencia_empaque le ON le.LicPlate=c.LicenciaEmpaque
LEFT JOIN Totales t ON t.ClaveLicencia=c.ClaveLicencia
LEFT JOIN dbo.bodega bo ON bo.IdBodega=le.IdBodega
OUTER APPLY (SELECT TOP(1) u.nombres,u.apellidos FROM dbo.usuario u
 WHERE u.IdUsuario=TRY_CONVERT(int,le.user_agr) AND u.IdEmpresa=bo.IdEmpresa) ug
OUTER APPLY (SELECT TOP(1) u.nombres,u.apellidos FROM dbo.usuario u
 WHERE u.IdUsuario=TRY_CONVERT(int,le.UsuarioUltimaImpresion) AND u.IdEmpresa=bo.IdEmpresa) ui
ORDER BY c.IdPedidoEnc,c.LicenciaEmpaque;
WITH Packing AS (
 SELECT pk.*,
 CAST(pk.IdPedidoEnc AS varchar(20)) + '|' +
 CASE WHEN NULLIF(LTRIM(RTRIM(pk.no_linea)),'') IS NULL THEN 'P|' + CAST(pk.IdPackingEnc AS varchar(20))
 ELSE 'L|' + UPPER(LTRIM(RTRIM(pk.no_linea))) END ClaveLicencia,
 CASE WHEN NULLIF(LTRIM(RTRIM(pk.no_linea)),'') IS NULL THEN '(SIN LICENCIA #' + CAST(pk.IdPackingEnc AS varchar(20)) + ')'
 ELSE UPPER(LTRIM(RTRIM(pk.no_linea))) END LicenciaEmpaque
 FROM dbo.trans_packing_enc pk
 WHERE pk.IdPickingEnc=@Picking AND pk.IdBodega=@Bodega
)
SELECT pk.ClaveLicencia,pk.IdPackingEnc,pk.IdBodega,pk.IdPickingEnc,pk.IdPedidoEnc,
 pk.LicenciaEmpaque,pk.Lic_plate LicenciaOrigen,pk.IdProductoBodega,
 p.codigo CodigoProducto,p.nombre Producto,pk.IdProductoEstado,
 pk.IdPresentacion,pp.nombre Presentacion,pp.factor FactorPresentacion,
 pk.IdUnidadMedida,um.Nombre UnidadMedida,pk.Lote,
 CASE WHEN pk.Fecha_vence>'19000101' THEN pk.Fecha_vence END FechaVence,
 pk.Cantidad_bultos_packing CantidadRegistrada,
 pk.Cantidad_camas_packing CamasRegistradas,pk.IdOperadorBodega,
 pk.usr_agr OperadorRegistro,
 CASE WHEN pk.Fecha_packing>'19000101' THEN pk.Fecha_packing END FechaRegistroPacking,
 CASE WHEN pk.fec_agr>'19000101' THEN pk.fec_agr END FechaCreacionRegistro,
 CASE WHEN pk.fec_mod>'19000101' THEN pk.fec_mod END FechaUltimaModificacion,
 pk.usr_mod UsuarioUltimaModificacion,pk.Finalizado,pk.Entregado,
 CASE WHEN pk.fecha_entrega>'19000101' THEN pk.fecha_entrega END FechaEntrega,
 pk.IdOperadorBodegaEntrega,pk.host_entrega HostEntrega,pk.IdProductoTallaColor
FROM Packing pk
LEFT JOIN dbo.producto_bodega pb ON pb.IdProductoBodega=pk.IdProductoBodega AND pb.IdBodega=pk.IdBodega
LEFT JOIN dbo.producto p ON p.IdProducto=pb.IdProducto
LEFT JOIN dbo.producto_presentacion pp ON pp.IdPresentacion=pk.IdPresentacion
LEFT JOIN dbo.unidad_medida um ON um.IdUnidadMedida=pk.IdUnidadMedida
ORDER BY pk.IdPedidoEnc,pk.LicenciaEmpaque,pk.IdPackingEnc;
SELECT IdPickingEnc,IdBodega,Requiere_Preparacion,Tipo_Preparacion,Estado_Preparacion,
 CASE WHEN Fecha_Inicio_Preparacion>'19000101' THEN Fecha_Inicio_Preparacion END InicioPreparacion,
 CASE WHEN Fecha_Fin_Preparacion>'19000101' THEN Fecha_Fin_Preparacion END FinPreparacion,
 CASE WHEN Estado_Preparacion='Finalizado' AND Fecha_Inicio_Preparacion>'19000101'
 AND Fecha_Fin_Preparacion>=Fecha_Inicio_Preparacion THEN
 CAST(DATEDIFF_BIG(SECOND,Fecha_Inicio_Preparacion,Fecha_Fin_Preparacion)/60.0 AS decimal(18,2)) END MinPreparacionPicking,
 CASE WHEN Fecha_Fin_Preparacion>'19000101' AND
 (Fecha_Inicio_Preparacion<='19000101' OR Fecha_Inicio_Preparacion IS NULL OR Fecha_Fin_Preparacion<Fecha_Inicio_Preparacion)
 THEN 'REVISAR FECHAS'
 WHEN Estado_Preparacion='Finalizado' AND (Fecha_Inicio_Preparacion IS NULL OR Fecha_Inicio_Preparacion<='19000101'
 OR Fecha_Fin_Preparacion IS NULL OR Fecha_Fin_Preparacion<='19000101') THEN 'CIERRE SIN FECHAS COMPLETAS'
 WHEN Fecha_Inicio_Preparacion IS NULL OR Fecha_Inicio_Preparacion<='19000101' THEN 'SIN INICIO REGISTRADO'
 WHEN Estado_Preparacion<>'Finalizado' THEN 'EN CURSO / SIN CIERRE'
 ELSE 'INTERVALO REGISTRADO' END CalidadMedicion
FROM dbo.trans_picking_enc WHERE IdPickingEnc=@Picking AND IdBodega=@Bodega;
