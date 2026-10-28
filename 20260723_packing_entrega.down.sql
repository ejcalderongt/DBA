SET XACT_ABORT ON;
BEGIN TRANSACTION;

DELETE FROM dbo.menu_rol_op
WHERE IdMenuSistemaOP = N'1.17';

DELETE FROM dbo.menu_sistema_op
WHERE IdMenuSistemaOP = N'1.17';

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.trans_packing_enc')
      AND name = 'IX_trans_packing_enc_entrega'
)
    DROP INDEX IX_trans_packing_enc_entrega ON dbo.trans_packing_enc;

IF COL_LENGTH('dbo.trans_packing_enc', 'host_entrega') IS NOT NULL
    ALTER TABLE dbo.trans_packing_enc DROP COLUMN host_entrega;

IF COL_LENGTH('dbo.trans_packing_enc', 'IdOperadorBodegaEntrega') IS NOT NULL
    ALTER TABLE dbo.trans_packing_enc DROP COLUMN IdOperadorBodegaEntrega;

IF COL_LENGTH('dbo.trans_packing_enc', 'fecha_entrega') IS NOT NULL
    ALTER TABLE dbo.trans_packing_enc DROP COLUMN fecha_entrega;

IF COL_LENGTH('dbo.trans_packing_enc', 'entregado') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.DF_trans_packing_enc_entregado', 'D') IS NOT NULL
        ALTER TABLE dbo.trans_packing_enc DROP CONSTRAINT DF_trans_packing_enc_entregado;
    ALTER TABLE dbo.trans_packing_enc DROP COLUMN entregado;
END;

IF COL_LENGTH('dbo.trans_picking_enc', 'confirmar_packing_entrega') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.DF_trans_picking_enc_confirmar_packing_entrega', 'D') IS NOT NULL
        ALTER TABLE dbo.trans_picking_enc DROP CONSTRAINT DF_trans_picking_enc_confirmar_packing_entrega;
    ALTER TABLE dbo.trans_picking_enc DROP COLUMN confirmar_packing_entrega;
END;

IF COL_LENGTH('dbo.trans_pe_enc', 'confirmar_packing_entrega') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.DF_trans_pe_enc_confirmar_packing_entrega', 'D') IS NOT NULL
        ALTER TABLE dbo.trans_pe_enc DROP CONSTRAINT DF_trans_pe_enc_confirmar_packing_entrega;
    ALTER TABLE dbo.trans_pe_enc DROP COLUMN confirmar_packing_entrega;
END;

IF COL_LENGTH('dbo.trans_pe_tipo', 'confirmar_packing_entrega') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.DF_trans_pe_tipo_confirmar_packing_entrega', 'D') IS NOT NULL
        ALTER TABLE dbo.trans_pe_tipo DROP CONSTRAINT DF_trans_pe_tipo_confirmar_packing_entrega;
    ALTER TABLE dbo.trans_pe_tipo DROP COLUMN confirmar_packing_entrega;
END;

COMMIT TRANSACTION;
