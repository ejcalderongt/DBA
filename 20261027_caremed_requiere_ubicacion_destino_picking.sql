-- #EJC20261027_CAREMED_PICKING_SCHEMA
-- Contrato verificado contra TOMWMS_MHS_DEV y clsLnTrans_pe_tipo.
-- El valor inicial 0 conserva la opción desactivada; no habilita flujos.
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar bit = 0;
IF DB_NAME() <> N'TOMWMS_CAREMED_PRD'
    THROW 50001, 'Destino incorrecto: se requiere TOMWMS_CAREMED_PRD.', 1;
IF OBJECT_ID(N'dbo.trans_pe_tipo', N'U') IS NULL
    THROW 50002, 'No existe dbo.trans_pe_tipo.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    IF COL_LENGTH(N'dbo.trans_pe_tipo', N'requiere_ubicacion_destino_picking') IS NULL
    BEGIN
        ALTER TABLE dbo.trans_pe_tipo
            ADD requiere_ubicacion_destino_picking bit NOT NULL
                CONSTRAINT DF_trans_pe_tipo_requiere_ubicacion_destino_picking
                DEFAULT (0) WITH VALUES;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.trans_pe_tipo')
          AND name = N'requiere_ubicacion_destino_picking'
          AND system_type_id = TYPE_ID(N'bit') AND is_nullable = 0
          AND default_object_id <> 0
    )
        THROW 50003, 'La columna existente no cumple el contrato esperado.', 1;

    IF @Aplicar = 1 COMMIT TRANSACTION;
    ELSE ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
