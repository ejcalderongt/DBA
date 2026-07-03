SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_p_paramext_empresa_id'
          AND object_id = OBJECT_ID('dbo.p_paramext')
    )
    BEGIN
        DROP INDEX IX_p_paramext_empresa_id ON dbo.p_paramext;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_d_movd_almacen_corel_producto'
          AND object_id = OBJECT_ID('dbo.d_movd_almacen')
    )
    BEGIN
        DROP INDEX IX_d_movd_almacen_corel_producto ON dbo.d_movd_almacen;
    END

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_p_producto_firebase_empresa_sucursal_idprod'
          AND object_id = OBJECT_ID('dbo.p_producto_firebase')
    )
    BEGIN
        DROP INDEX IX_p_producto_firebase_empresa_sucursal_idprod ON dbo.p_producto_firebase;
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
