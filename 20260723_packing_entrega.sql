SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- #EJC20260723_PACKING_ENTREGA: configuración y snapshot del flujo post-packing.
IF COL_LENGTH('dbo.trans_pe_tipo', 'confirmar_packing_entrega') IS NULL
BEGIN
    ALTER TABLE dbo.trans_pe_tipo
        ADD confirmar_packing_entrega bit NOT NULL
            CONSTRAINT DF_trans_pe_tipo_confirmar_packing_entrega DEFAULT (0);
END;

IF COL_LENGTH('dbo.trans_pe_enc', 'confirmar_packing_entrega') IS NULL
BEGIN
    ALTER TABLE dbo.trans_pe_enc
        ADD confirmar_packing_entrega bit NOT NULL
            CONSTRAINT DF_trans_pe_enc_confirmar_packing_entrega DEFAULT (0);
END;

IF COL_LENGTH('dbo.trans_picking_enc', 'confirmar_packing_entrega') IS NULL
BEGIN
    ALTER TABLE dbo.trans_picking_enc
        ADD confirmar_packing_entrega bit NOT NULL
            CONSTRAINT DF_trans_picking_enc_confirmar_packing_entrega DEFAULT (0);
END;

-- La entrega se confirma por IdPedidoEnc + no_linea y actualiza todas las filas
-- que componen la licencia packing/caja master.
IF COL_LENGTH('dbo.trans_packing_enc', 'entregado') IS NULL
BEGIN
    ALTER TABLE dbo.trans_packing_enc
        ADD entregado bit NOT NULL
            CONSTRAINT DF_trans_packing_enc_entregado DEFAULT (0);
END;

IF COL_LENGTH('dbo.trans_packing_enc', 'fecha_entrega') IS NULL
    ALTER TABLE dbo.trans_packing_enc ADD fecha_entrega datetime NULL;

IF COL_LENGTH('dbo.trans_packing_enc', 'IdOperadorBodegaEntrega') IS NULL
    ALTER TABLE dbo.trans_packing_enc ADD IdOperadorBodegaEntrega int NULL;

IF COL_LENGTH('dbo.trans_packing_enc', 'host_entrega') IS NULL
    ALTER TABLE dbo.trans_packing_enc ADD host_entrega nvarchar(100) NULL;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.trans_packing_enc')
      AND name = 'IX_trans_packing_enc_entrega'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trans_packing_enc_entrega
        ON dbo.trans_packing_enc
        (
            IdPedidoEnc,
            no_linea,
            finalizado,
            entregado,
            IdDespachoEnc
        )
        INCLUDE
        (
            IdPickingEnc,
            IdProductoBodega,
            IdProductoEstado,
            IdPresentacion,
            IdUnidadMedida,
            cantidad_bultos_packing,
            lic_plate
        );
END;

-- Opción HH. En MHS-DEV el rol operativo equivalente es Auxiliar de Bodega (2).
IF NOT EXISTS (
    SELECT 1 FROM dbo.menu_sistema_op WHERE IdMenuSistemaOP = N'1.17'
)
BEGIN
    INSERT INTO dbo.menu_sistema_op
        (IdMenuSistemaOP, IdTipoTarea, Nombre, Nivel, Padre, Posicion)
    VALUES
        (N'1.17', 29, N'Entrega packing', 2, N'1', 17);
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.menu_rol_op
    WHERE IdMenuSistemaOP = N'1.17'
      AND IdRolOperador = 2
)
BEGIN
    INSERT INTO dbo.menu_rol_op
        (IdMenuSistemaOP, IdRolOperador, user_agr, fec_agr, visible, activo)
    VALUES
        (N'1.17', 2, N'#EJC20260723_PACKING_ENTREGA', GETDATE(), 1, 1);
END;

COMMIT TRANSACTION;
