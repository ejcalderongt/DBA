SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_picking_ubic_kpi_clean_fecha'
          AND object_id = OBJECT_ID('dbo.trans_picking_ubic')
    )
    BEGIN
        DROP INDEX IX_trans_picking_ubic_kpi_clean_fecha ON dbo.trans_picking_ubic;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_despacho_det_kpi_fecagr'
          AND object_id = OBJECT_ID('dbo.trans_despacho_det')
    )
    BEGIN
        DROP INDEX IX_trans_despacho_det_kpi_fecagr ON dbo.trans_despacho_det;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_pe_enc_kpi_fechapedido'
          AND object_id = OBJECT_ID('dbo.trans_pe_enc')
    )
    BEGIN
        DROP INDEX IX_trans_pe_enc_kpi_fechapedido ON dbo.trans_pe_enc;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_picking_ubic_kpi_pedido_producto'
          AND object_id = OBJECT_ID('dbo.trans_picking_ubic')
    )
    BEGIN
        DROP INDEX IX_trans_picking_ubic_kpi_pedido_producto ON dbo.trans_picking_ubic;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_packing_enc_kpi_despacho'
          AND object_id = OBJECT_ID('dbo.trans_packing_enc')
    )
    BEGIN
        DROP INDEX IX_trans_packing_enc_kpi_despacho ON dbo.trans_packing_enc;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_despacho_enc_kpi_fecha'
          AND object_id = OBJECT_ID('dbo.trans_despacho_enc')
    )
    BEGIN
        DROP INDEX IX_trans_despacho_enc_kpi_fecha ON dbo.trans_despacho_enc;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_trans_picking_ubic_kpi_verificacion_fecha'
          AND object_id = OBJECT_ID('dbo.trans_picking_ubic')
    )
    BEGIN
        DROP INDEX IX_trans_picking_ubic_kpi_verificacion_fecha ON dbo.trans_picking_ubic;
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
