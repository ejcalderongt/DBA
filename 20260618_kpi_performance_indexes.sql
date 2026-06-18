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

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_picking_ubic_kpi_pedido_producto'
          AND object_id = OBJECT_ID('dbo.trans_picking_ubic')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_picking_ubic_kpi_pedido_producto
        ON dbo.trans_picking_ubic (
            IdPedidoEnc,
            IdPedidoDet,
            IdProductoBodega,
            IdPickingEnc,
            IdPickingUbic,
            IdPickingDet
        )
        INCLUDE (
            IdOperadorBodega_Pickeo,
            IdOperadorBodega_Verifico,
            IdProductoEstado,
            cantidad_solicitada,
            cantidad_recibida,
            cantidad_verificada,
            fecha_picking,
            fecha_verificado,
            fecha_vence,
            lic_plate,
            IdStock,
            dañado_picking,
            dañado_verificacion,
            no_encontrado
        );
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_packing_enc_kpi_despacho'
          AND object_id = OBJECT_ID('dbo.trans_packing_enc')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_packing_enc_kpi_despacho
        ON dbo.trans_packing_enc (
            iddespachoenc,
            lic_plate,
            idproductobodega
        )
        INCLUDE (
            no_linea
        );
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_despacho_enc_kpi_fecha'
          AND object_id = OBJECT_ID('dbo.trans_despacho_enc')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_despacho_enc_kpi_fecha
        ON dbo.trans_despacho_enc (
            fecha,
            IdDespachoEnc
        )
        INCLUDE (
            IdPropietarioBodega,
            IdVehiculo,
            IdRuta,
            IdPiloto,
            no_pase,
            observacion,
            numero,
            marchamo
        );
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_picking_ubic_kpi_verificacion_fecha'
          AND object_id = OBJECT_ID('dbo.trans_picking_ubic')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_picking_ubic_kpi_verificacion_fecha
        ON dbo.trans_picking_ubic (
            fecha_verificado,
            IdPickingDet,
            IdPedidoDet,
            IdProductoBodega,
            IdPickingEnc
        )
        INCLUDE (
            IdProductoEstado,
            cantidad_solicitada,
            cantidad_recibida,
            cantidad_verificada,
            fecha_vence,
            lic_plate,
            IdBodega,
            IdOperadorBodega_Verifico
        )
        WHERE dañado_picking = 0
          AND dañado_verificacion = 0
          AND no_encontrado = 0;
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
