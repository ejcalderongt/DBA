/*
    #EJC20260717_DSP_AUDITORIA_READONLY
    Objetivo:
      Diagnosticar, sin modificar datos, la coherencia pedido -> picking -> despacho -> SAP
      y detectar reservas/stock que sobrevivieron a cantidades ya despachadas.

    Uso:
      Asignar al menos uno de los parámetros. El script contiene únicamente SELECT.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdDespachoEnc INT = NULL;
DECLARE @IdPedidoEnc   INT = 5874;
DECLARE @IdPickingEnc  INT = 2542;

IF @IdDespachoEnc IS NULL AND @IdPedidoEnc IS NULL AND @IdPickingEnc IS NULL
    THROW 50001, 'Debe indicar IdDespachoEnc, IdPedidoEnc o IdPickingEnc.', 1;

;WITH Lineas AS
(
    SELECT DISTINCT
        pu.IdPedidoEnc,
        pe.IdPickingEnc,
        pu.IdPedidoDet,
        pu.IdPickingUbic,
        pu.IdStock,
        pu.IdStockRes,
        pu.cantidad_solicitada,
        pu.cantidad_verificada,
        pu.cantidad_despachada,
        ped.Cantidad AS cantidad_pedido,
        ped.Cant_despachada AS cantidad_despachada_pedido
    FROM trans_picking_ubic pu
    INNER JOIN trans_pe_enc pe ON pe.IdPedidoEnc = pu.IdPedidoEnc
    INNER JOIN trans_pe_det ped ON ped.IdPedidoDet = pu.IdPedidoDet
    WHERE (@IdPedidoEnc IS NULL OR pu.IdPedidoEnc = @IdPedidoEnc)
      AND (@IdPickingEnc IS NULL OR pe.IdPickingEnc = @IdPickingEnc)
      AND (@IdDespachoEnc IS NULL OR EXISTS
          (SELECT 1 FROM trans_despacho_det dd
           WHERE dd.IdDespachoEnc = @IdDespachoEnc
             AND dd.IdPickingUbic = pu.IdPickingUbic))
), Despacho AS
(
    SELECT dd.IdPickingUbic,
           SUM(dd.CantidadDespachada) AS cantidad_despacho_det,
           COUNT(DISTINCT dd.IdDespachoEnc) AS despachos
    FROM trans_despacho_det dd
    INNER JOIN Lineas l ON l.IdPickingUbic = dd.IdPickingUbic
    GROUP BY dd.IdPickingUbic
), Salida AS
(
    SELECT dd.IdPickingUbic,
           SUM(o.Cantidad) AS cantidad_salida_sap,
           SUM(CASE WHEN o.enviado = 1 THEN o.Cantidad ELSE 0 END) AS cantidad_sap_enviada
    FROM trans_despacho_det dd
    INNER JOIN Lineas l ON l.IdPickingUbic = dd.IdPickingUbic
    LEFT JOIN i_nav_transacciones_out o
      ON o.IdDespachoEnc = dd.IdDespachoEnc
     AND o.IdDespachoDet = dd.IdDespachoDet
    GROUP BY dd.IdPickingUbic
)
SELECT
    l.*,
    ISNULL(d.cantidad_despacho_det, 0) AS cantidad_despacho_det,
    ISNULL(s.cantidad_salida_sap, 0) AS cantidad_salida_sap,
    ISNULL(s.cantidad_sap_enviada, 0) AS cantidad_sap_enviada,
    sr.cantidad AS reserva_actual,
    st.cantidad AS stock_actual,
    CASE WHEN l.cantidad_despachada > 0 AND sr.IdStockRes IS NOT NULL THEN 1 ELSE 0 END AS alerta_reserva_sobreviviente,
    CASE WHEN ABS(ISNULL(d.cantidad_despacho_det, 0) - l.cantidad_despachada) > 0.000001 THEN 1 ELSE 0 END AS alerta_picking_vs_despacho,
    CASE WHEN ABS(ISNULL(d.cantidad_despacho_det, 0) - ISNULL(s.cantidad_salida_sap, 0)) > 0.000001 THEN 1 ELSE 0 END AS alerta_despacho_vs_sap
FROM Lineas l
LEFT JOIN Despacho d ON d.IdPickingUbic = l.IdPickingUbic
LEFT JOIN Salida s ON s.IdPickingUbic = l.IdPickingUbic
LEFT JOIN stock_res sr ON sr.IdStockRes = l.IdStockRes
LEFT JOIN stock st ON st.IdStock = l.IdStock
ORDER BY l.IdPedidoEnc, l.IdPedidoDet, l.IdPickingUbic;

-- Resumen por detalle de pedido. La comparación directa aplica cuando pedido y picking
-- están expresados en la misma unidad; las líneas con presentación deben revisarse con factor.
SELECT
    ped.IdPedidoEnc,
    ped.IdPedidoDet,
    ped.IdPresentacion,
    ped.Cantidad,
    ped.Cant_despachada,
    SUM(ISNULL(dd.CantidadDespachada, 0)) AS total_despacho_det,
    CASE
        WHEN ped.IdPresentacion = 0
         AND ABS(ped.Cant_despachada - SUM(ISNULL(dd.CantidadDespachada, 0))) > 0.000001 THEN 1
        ELSE 0
    END AS alerta_pedido_vs_despacho_misma_unidad
FROM trans_pe_det ped
INNER JOIN trans_pe_enc pe ON pe.IdPedidoEnc = ped.IdPedidoEnc
LEFT JOIN trans_despacho_det dd ON dd.IdPedidoDet = ped.IdPedidoDet
WHERE (@IdPedidoEnc IS NULL OR ped.IdPedidoEnc = @IdPedidoEnc)
  AND (@IdPickingEnc IS NULL OR pe.IdPickingEnc = @IdPickingEnc)
  AND (@IdDespachoEnc IS NULL OR dd.IdDespachoEnc = @IdDespachoEnc)
GROUP BY ped.IdPedidoEnc, ped.IdPedidoDet, ped.IdPresentacion, ped.Cantidad, ped.Cant_despachada
ORDER BY ped.IdPedidoEnc, ped.IdPedidoDet;

