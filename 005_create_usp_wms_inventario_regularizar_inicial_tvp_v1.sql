CREATE OR ALTER PROCEDURE dbo.usp_wms_inventario_regularizar_inicial_tvp_v1
    @IdInventarioEnc INT,
    @IdTipoInventario INT,
    @IdBodega INT,
    @Stocks dbo.tvp_wms_inventario_regularizacion_stock_v1 READONLY,
    @Movimientos dbo.tvp_wms_inventario_regularizacion_mov_v1 READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    BEGIN TRY
        UPDATE dbo.trans_inv_enc
        SET regularizado = 1,
            estado = N'Finalizado',
            activo = 0
        WHERE idinventarioenc = @IdInventarioEnc;

        ;WITH base AS (
            SELECT s.*,
                   ROW_NUMBER() OVER (ORDER BY s.RowId) AS rn
            FROM @Stocks s
            WHERE ISNULL(s.cantidad, 0) > 0
              AND @IdTipoInventario IN (1, 2)
        )
        INSERT INTO dbo.stock (
            IdBodega, IdPropietarioBodega, IdProductoBodega, IdProductoEstado,
            IdPresentacion, IdUnidadMedida, IdUbicacion, IdUbicacion_anterior,
            IdRecepcionEnc, IdRecepcionDet, IdPedidoEnc, IdPickingEnc, IdDespachoEnc,
            lote, lic_plate, serial, cantidad, fecha_ingreso, fecha_vence, uds_lic_plate,
            no_bulto, fecha_manufactura, user_agr, fec_agr, user_mod, fec_mod,
            activo, peso, temperatura, atributo_variante_1, pallet_no_estandar, IdProductoTallaColor
        )
        SELECT
            b.IdBodega,
            b.IdPropietarioBodega,
            b.IdProductoBodega,
            b.IdProductoEstado,
            b.IdPresentacion,
            b.IdUnidadMedida,
            b.IdUbicacion,
            b.IdUbicacion_anterior,
            b.IdRecepcionEnc,
            b.IdRecepcionDet,
            b.IdPedidoEnc,
            b.IdPickingEnc,
            b.IdDespachoEnc,
            b.lote,
            b.lic_plate,
            b.serial,
            b.cantidad,
            b.fecha_ingreso,
            b.fecha_vence,
            b.uds_lic_plate,
            b.no_bulto,
            b.fecha_manufactura,
            b.user_agr,
            b.fec_agr,
            b.user_mod,
            b.fec_mod,
            b.activo,
            b.peso,
            b.temperatura,
            b.atributo_variante_1,
            b.pallet_no_estandar,
            b.IdProductoTallaColor
        FROM base b;

        ;WITH mov AS (
            SELECT m.*,
                   ROW_NUMBER() OVER (ORDER BY m.RowId) AS rn
            FROM @Movimientos m
        )
        INSERT INTO dbo.trans_movimientos (
            IdEmpresa, IdBodegaOrigen, IdTransaccion,
            IdPropietarioBodega, IdProductoBodega, IdUbicacionOrigen, IdUbicacionDestino,
            IdPresentacion, IdEstadoOrigen, IdEstadoDestino, IdUnidadMedida,
            IdTipoTarea, IdBodegaDestino, IdRecepcion, cantidad, serie, peso, lote,
            fecha_vence, fecha, barra_pallet, hora_ini, hora_fin, fecha_agr, usuario_agr,
            cantidad_hist, peso_hist, lic_plate, IdOperadorBodega, IdRecepcionDet,
            IdPedidoEnc, IdPedidoDet, IdDespachoEnc, IdDespachoDet, IdProductoTallaColor,
            Talla, Color
        )
        SELECT
            mov.IdEmpresa,
            mov.IdBodegaOrigen,
            mov.IdTransaccion,
            mov.IdPropietarioBodega,
            mov.IdProductoBodega,
            mov.IdUbicacionOrigen,
            mov.IdUbicacionDestino,
            mov.IdPresentacion,
            mov.IdEstadoOrigen,
            mov.IdEstadoDestino,
            mov.IdUnidadMedida,
            mov.IdTipoTarea,
            mov.IdBodegaDestino,
            mov.IdRecepcion,
            mov.cantidad,
            mov.serie,
            mov.peso,
            mov.lote,
            mov.fecha_vence,
            mov.fecha,
            mov.barra_pallet,
            mov.hora_ini,
            mov.hora_fin,
            mov.fecha_agr,
            mov.usuario_agr,
            mov.cantidad_hist,
            mov.peso_hist,
            mov.lic_plate,
            mov.IdOperadorBodega,
            mov.IdRecepcionDet,
            mov.IdPedidoEnc,
            mov.IdPedidoDet,
            mov.IdDespachoEnc,
            mov.IdDespachoDet,
            mov.IdProductoTallaColor,
            mov.Talla,
            mov.Color
        FROM mov;

        UPDATE dbo.tarea_hh
        SET IdEstado = 4
        WHERE IdTransaccion = @IdInventarioEnc
          AND IdTipoTarea = 6;

        COMMIT TRAN;

        SELECT
            StockInsertados = (SELECT COUNT(1) FROM @Stocks WHERE ISNULL(cantidad, 0) > 0 AND @IdTipoInventario IN (1, 2)),
            MovInsertados = (SELECT COUNT(1) FROM @Movimientos);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
