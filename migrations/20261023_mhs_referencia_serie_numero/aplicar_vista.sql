-- #EJC20261023_REFERENCIA_SERIE_NUMERO
SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_MHS_DEV' OR CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) <> N'MHS-APP-QA' THROW 51000, 'Destino no autorizado.', 1;
BEGIN TRANSACTION;
EXEC sys.sp_executesql N'
ALTER VIEW [dbo].[VW_Get_Single_Pedido]
AS
SELECT     dbo.trans_pe_enc.IdPedidoEnc, dbo.trans_pe_enc.IdBodega, dbo.trans_pe_enc.IdCliente, dbo.trans_pe_enc.IdMuelle, dbo.trans_pe_enc.IdPropietarioBodega, dbo.trans_pe_enc.IdTipoPedido, dbo.trans_pe_enc.IdPickingEnc, dbo.trans_pe_enc.Fecha_Pedido, dbo.trans_pe_enc.hora_ini, 
                  dbo.trans_pe_enc.hora_fin, dbo.trans_pe_enc.ubicacion, dbo.trans_pe_enc.estado, dbo.trans_pe_enc.no_despacho, dbo.trans_pe_enc.activo, dbo.trans_pe_enc.user_agr, dbo.trans_pe_enc.fec_agr, dbo.trans_pe_enc.user_mod, dbo.trans_pe_enc.fec_mod, 
                  dbo.trans_pe_enc.no_documento, dbo.trans_pe_enc.local, dbo.trans_pe_enc.pallet_primero, dbo.trans_pe_enc.dias_cliente, dbo.trans_pe_enc.anulado, dbo.trans_pe_enc.RoadKilometraje, dbo.trans_pe_enc.RoadFechaEntr, dbo.trans_pe_enc.RoadDirEntrega, 
                  dbo.trans_pe_enc.RoadTotal, dbo.trans_pe_enc.RoadDesMonto, dbo.trans_pe_enc.RoadImpMonto, dbo.trans_pe_enc.RoadPeso, dbo.trans_pe_enc.RoadBandera, dbo.trans_pe_enc.RoadStatCom, dbo.trans_pe_enc.RoadCalcoBJ, dbo.trans_pe_enc.RoadImpres, 
                  dbo.trans_pe_enc.RoadADD1, dbo.trans_pe_enc.RoadADD2, dbo.trans_pe_enc.RoadADD3, dbo.trans_pe_enc.RoadStatProc, dbo.trans_pe_enc.RoadRechazado, dbo.trans_pe_enc.RoadRazon_Rechazado, dbo.trans_pe_enc.RoadInformado, dbo.trans_pe_enc.RoadSucursal, 
                  dbo.trans_pe_enc.RoadIdDespacho, dbo.trans_pe_enc.RoadIdFacturacion, dbo.trans_pe_enc.RoadIdRuta, dbo.trans_pe_enc.RoadIdVendedor, dbo.trans_pe_enc.RoadIdRutaDespacho, dbo.trans_pe_enc.RoadIdVendedorDespacho, dbo.trans_pe_enc.Observacion, 
                  dbo.trans_pe_enc.PedidoRoad, dbo.trans_pe_enc.HoraEntregaDesde, dbo.trans_pe_enc.HoraEntregaHasta, dbo.trans_pe_enc.referencia, dbo.trans_pe_enc.IdMotivoAnulacionBodega, dbo.trans_pe_enc.Enviado_A_ERP, dbo.trans_pe_enc.control_ultimo_lote, dbo.trans_pe_enc.serie, 
                  dbo.trans_pe_enc.correlativo, dbo.trans_pe_enc.Referencia_Documento_Ingreso_Bodega_Destino, dbo.trans_pe_enc.sync_mi3, dbo.trans_pe_tipo.Nombre AS Nombre_Tipo_Pedido, dbo.cliente.nombre_comercial AS Nombre_Cliente, 
                  dbo.propietarios.nombre_comercial AS Nombre_Propietario, dbo.propietario_bodega.IdPropietario, dbo.cliente.codigo AS Codigo_Cliente, dbo.cliente.es_bodega_recepcion, dbo.cliente.es_bodega_traslado, dbo.cliente.idubicacionvirtual, 
                  dbo.cliente.control_ultimo_lote AS control_ultimo_lote_cliente, dbo.trans_pe_enc.No_Picking_ERP, dbo.trans_pe_enc.fecha_preparacion, dbo.trans_pe_enc.IdTipoManufactura, dbo.trans_pe_enc.bodega_origen, dbo.trans_pe_enc.IdMotivoDevolucion, CASE WHEN c1.codigo IS NULL 
                  THEN '''' ELSE ISNULL(concat(c1.codigo, '' - '', c1.nombre_comercial), '''') END AS bodega_destino, dbo.trans_pe_tipo.permitir_despacho_parcial, dbo.trans_pe_tipo.permitir_despacho_multiple, ISNULL(dbo.trans_pe_tipo.empaque_tarima, 0) AS empaque_tarima, 
                  dbo.trans_pe_enc.bodega_destino AS Expr1, dbo.trans_pe_enc.no_documento_externo, dbo.trans_pe_enc.requiere_tarimas, dbo.trans_pe_enc.Codigo_Empresa_ERP,trans_pe_enc.EsExportacion, trans_pe_enc.guia_transporte, 
				  trans_pe_enc.IdEmpresaTransporte, trans_pe_enc.IdPiloto, dbo.trans_pe_tipo.asignar_todos_operadores, dbo.trans_pe_tipo.verificar, dbo.trans_pe_tipo.generar_picking_auto,
                  trans_pe_enc.tipo_solicitud_erp, trans_pe_enc.comentarios, dbo.trans_pe_enc.Referencia_Serie_Numero
FROM        dbo.propietarios INNER JOIN
                  dbo.propietario_bodega ON dbo.propietarios.IdPropietario = dbo.propietario_bodega.IdPropietario RIGHT OUTER JOIN
                  dbo.trans_pe_enc ON dbo.propietario_bodega.IdPropietarioBodega = dbo.trans_pe_enc.IdPropietarioBodega LEFT OUTER JOIN
                  dbo.trans_pe_tipo ON dbo.trans_pe_enc.IdTipoPedido = dbo.trans_pe_tipo.IdTipoPedido LEFT OUTER JOIN
                  dbo.cliente ON dbo.trans_pe_enc.IdCliente = dbo.cliente.IdCliente LEFT OUTER JOIN
                  dbo.cliente AS c1 ON c1.codigo COLLATE Modern_Spanish_CI_AS = dbo.trans_pe_enc.bodega_destino
';
COMMIT;