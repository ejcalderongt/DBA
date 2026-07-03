-- EJC 20260701
-- Bitacora del cambio para soportar multiples bobinas por la misma linea
-- en i_nav_ped_compra_det_lote.
--
-- Objetivo:
-- - Conservar las columnas funcionales existentes.
-- - Agregar una llave tecnica estable por fila.
-- - Permitir multiples registros para la misma combinacion
--   NoEnc + Source_Prod_Order_Line + Item_No.
-- - Mantener un indice de consulta por documento/linea/producto.

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    IF COL_LENGTH('dbo.i_nav_ped_compra_det_lote', 'IdNavPedCompraDetLote') IS NULL
    BEGIN
        ALTER TABLE dbo.i_nav_ped_compra_det_lote
        ADD IdNavPedCompraDetLote INT IDENTITY(1,1) NOT NULL;
    END;

    DECLARE @PkName sysname;

    SELECT @PkName = kc.name
    FROM sys.key_constraints kc
    WHERE kc.parent_object_id = OBJECT_ID(N'dbo.i_nav_ped_compra_det_lote')
      AND kc.type = 'PK';

    IF @PkName IS NOT NULL
    BEGIN
        DECLARE @DropSql NVARCHAR(MAX) = N'ALTER TABLE dbo.i_nav_ped_compra_det_lote DROP CONSTRAINT ' + QUOTENAME(@PkName) + N';';
        EXEC(@DropSql);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.i_nav_ped_compra_det_lote')
          AND [name] = N'PK_i_nav_ped_compra_det_lote'
    )
    BEGIN
        ALTER TABLE dbo.i_nav_ped_compra_det_lote
        ADD CONSTRAINT PK_i_nav_ped_compra_det_lote
            PRIMARY KEY CLUSTERED (IdNavPedCompraDetLote);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.i_nav_ped_compra_det_lote')
          AND [name] = N'IX_i_nav_ped_compra_det_lote_NoEnc_Linea_Item'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_i_nav_ped_compra_det_lote_NoEnc_Linea_Item
        ON dbo.i_nav_ped_compra_det_lote (NoEnc, Source_Prod_Order_Line, Item_No)
        INCLUDE (Lot_No, Expiration_Date, Entry_No, Source_Type, Quantity_Base, Variant_Code, fec_agr, Pallet_Weight, Pallet_License_No);
    END;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
