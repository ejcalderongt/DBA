SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_p_paramext_empresa_id'
          AND object_id = OBJECT_ID('dbo.p_paramext')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_p_paramext_empresa_id
        ON dbo.p_paramext (
            empresa,
            id
        )
        INCLUDE (
            valor
        );
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_d_movd_almacen_corel_producto'
          AND object_id = OBJECT_ID('dbo.d_movd_almacen')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_d_movd_almacen_corel_producto
        ON dbo.d_movd_almacen (
            corel,
            producto
        )
        INCLUDE (
            cant,
            unidadmedida
        );
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_p_producto_firebase_empresa_sucursal_idprod'
          AND object_id = OBJECT_ID('dbo.p_producto_firebase')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_p_producto_firebase_empresa_sucursal_idprod
        ON dbo.p_producto_firebase (
            empresa,
            sucursal,
            idprod
        )
        INCLUDE (
            um,
            cant
        );
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
