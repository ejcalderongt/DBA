/*
  #EJC20260522_OC_READMODEL
  Read-model para carga de frmOrdenCompra.

  Objetivo:
    Reducir roundtrips por linea al abrir una orden de compra sobre enlaces
    cliente-servidor con latencia. El SP devuelve el detalle ya enriquecido con
    producto, clasificacion, unidad, presentacion, embarcador y talla/color.

  Contrato:
    - No escribe datos.
    - Mantiene columnas base requeridas por clsLnTrans_oc_det.Cargar.
    - Agrega aliases con prefijo para hidratar objetos sin llamadas por linea.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_wms_ordencompra_readmodel_v1
    @IdOrdenCompraEnc INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        p.IdProducto,
        det.IdOrdenCompraEnc,
        det.IdOrdenCompraDet,
        det.IdProductoBodega,
        det.IdArancel,
        det.IdPresentacion,
        det.IdUnidadMedidaBasica,
        det.IdMotivoDevolucion,
        det.No_Linea,
        det.nombre_producto,
        det.nombre_presentacion,
        det.nombre_arancel,
        det.porcentaje_arancel,
        det.nombre_unidad_medida_basica,
        det.cantidad,
        det.cantidad_recibida,
        det.costo,
        det.total_linea,
        det.user_agr,
        det.fec_agr,
        det.user_mod,
        det.fec_mod,
        det.activo,
        det.peso,
        det.peso_recibido,
        det.atributo_variante_1,
        det.codigo_producto,
        det.valor_aduana,
        det.valor_fob,
        det.valor_iva,
        det.valor_dai,
        det.valor_seguro,
        det.valor_flete,
        det.peso_neto,
        det.peso_bruto,
        det.IdPropietarioBodega,
        det.nombre_propietario,
        det.IdOrdenCompraDetPadre,
        det.IdEmbarcador,
        det.IdProductoTallaColor,
        det.camas_tarima,
        det.cajas_cama,

        p.IdProducto AS Producto_IdProducto,
        p.IdPropietario AS Producto_IdPropietario,
        p.IdClasificacion AS Producto_IdClasificacion,
        p.IdUnidadMedidaBasica AS Producto_IdUnidadMedidaBasica,
        p.codigo AS Producto_Codigo,
        p.nombre AS Producto_Nombre,
        p.kit AS Producto_Kit,
        p.control_peso AS Producto_ControlPeso,
        p.peso_referencia AS Producto_PesoReferencia,

        pc.IdClasificacion AS Clasificacion_IdClasificacion,
        pc.nombre AS Clasificacion_Nombre,
        pc.codigo AS Clasificacion_Codigo,

        um.IdUnidadMedida AS Unidad_IdUnidadMedida,
        um.codigo AS Unidad_Codigo,
        um.Nombre AS Unidad_Nombre,
        um.factor AS Unidad_Factor,

        pp.IdPresentacion AS Presentacion_IdPresentacion,
        pp.IdProducto AS Presentacion_IdProducto,
        pp.codigo_barra AS Presentacion_CodigoBarra,
        pp.nombre AS Presentacion_Nombre,
        pp.peso AS Presentacion_Peso,
        pp.factor AS Presentacion_Factor,
        pp.activo AS Presentacion_Activo,
        pp.EsPallet AS Presentacion_EsPallet,
        pp.Costo AS Presentacion_Costo,
        pp.CamasPorTarima AS Presentacion_CamasPorTarima,
        pp.CajasPorCama AS Presentacion_CajasPorCama,
        pp.IdPresentacionPallet AS Presentacion_IdPresentacionPallet,
        pp.codigo AS Presentacion_Codigo,

        emb.Nombre AS Embarcador_Nombre,

        ta.Codigo AS codigo_talla,
        co.Codigo AS codigo_color,
        ta.IdTalla,
        co.IdColor
    FROM dbo.trans_oc_det AS det
    INNER JOIN dbo.producto_bodega AS pb
        ON pb.IdProductoBodega = det.IdProductoBodega
    INNER JOIN dbo.producto AS p
        ON p.IdProducto = pb.IdProducto
    LEFT JOIN dbo.producto_clasificacion AS pc
        ON pc.IdClasificacion = p.IdClasificacion
    LEFT JOIN dbo.unidad_medida AS um
        ON um.IdUnidadMedida = det.IdUnidadMedidaBasica
    LEFT JOIN dbo.producto_presentacion AS pp
        ON pp.IdPresentacion = det.IdPresentacion
    LEFT JOIN dbo.trans_oc_embarcador AS emb
        ON emb.IdEmbarcador = det.IdEmbarcador
    LEFT JOIN dbo.producto_talla_color AS ptc
        ON ptc.IdProductoTallaColor = det.IdProductoTallaColor
    LEFT JOIN dbo.talla AS ta
        ON ta.IdTalla = ptc.IdTalla
    LEFT JOIN dbo.color AS co
        ON co.IdColor = ptc.IdColor
    WHERE det.IdOrdenCompraEnc = @IdOrdenCompraEnc
    ORDER BY det.No_Linea, det.IdOrdenCompraDet;
END;
GO
