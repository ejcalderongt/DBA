SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_picking_ubic_kpi_clean_fecha'
          AND object_id = OBJECT_ID('dbo.trans_picking_ubic')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_picking_ubic_kpi_clean_fecha
        ON dbo.trans_picking_ubic (
            fecha_picking,
            IdPedidoDet,
            IdProductoBodega,
            IdPickingEnc,
            IdOperadorBodega_Pickeo
        )
        INCLUDE (
            IdPickingUbic,
            IdStock,
            cantidad_recibida,
            fecha_vence,
            lic_plate,
            IdProductoEstado
        )
        WHERE dañado_picking = 0
          AND no_encontrado = 0
          AND dañado_verificacion = 0;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_despacho_det_kpi_fecagr'
          AND object_id = OBJECT_ID('dbo.trans_despacho_det')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_despacho_det_kpi_fecagr
        ON dbo.trans_despacho_det (
            fec_agr,
            IdPedidoEnc,
            IdPedidoDet,
            IdDespachoEnc
        )
        INCLUDE (
            IdPickingUbic,
            IdProductoBodega,
            CantidadDespachada,
            NombreEstado,
            user_agr
        )
        WHERE fec_agr IS NOT NULL
          AND CantidadDespachada > 0;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_pe_enc_kpi_fechapedido'
          AND object_id = OBJECT_ID('dbo.trans_pe_enc')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_pe_enc_kpi_fechapedido
        ON dbo.trans_pe_enc (
            Fecha_Pedido,
            IdPedidoEnc
        )
        INCLUDE (
            IdTipoPedido,
            estado,
            ubicacion,
            bodega_destino,
            IdCliente,
            Referencia_Documento_Ingreso_Bodega_Destino
        );
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
