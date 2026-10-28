/* #EJC20260716_K004_DESPACHO_DOCUMENTO_ERP
   Propósito:
   - Conservar cada documento SAP generado por pedido dentro de un despacho.
   - Evitar que trans_despacho_enc.no_pase sea sobrescrito cuando el despacho
     contiene más de un pedido/entrega.
   - Mantener trans_despacho_enc.no_pase sin cambios para compatibilidad legacy.

   Alcance: solo DDL. No migra datos históricos y no modifica no_pase.
   Despliegue recomendado: ejecutar primero en QA y validar el flujo KILLIOS.
   Ejecución: aplicado y validado en TOMWMS_KILLIOS_PRD el 2026-07-16. */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.trans_despacho_documento_erp', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.trans_despacho_documento_erp
        (
            IdDespachoDocumentoERP int IDENTITY(1,1) NOT NULL,
            IdDespachoEnc int NOT NULL,
            IdPedidoEnc int NOT NULL,
            CodigoEmpresaERP nvarchar(25) NOT NULL,
            TipoDocumentoERP varchar(25) NOT NULL,
            DocEntry int NOT NULL,
            DocNum int NOT NULL,
            Fecha datetime NOT NULL
                CONSTRAINT DF_trans_despacho_documento_erp_Fecha DEFAULT (GETDATE()),
            user_agr nvarchar(25) NOT NULL,
            fec_agr datetime NOT NULL
                CONSTRAINT DF_trans_despacho_documento_erp_fec_agr DEFAULT (GETDATE()),
            user_mod nvarchar(25) NULL,
            fec_mod datetime NULL,
            activo bit NOT NULL
                CONSTRAINT DF_trans_despacho_documento_erp_activo DEFAULT (1),

            CONSTRAINT PK_trans_despacho_documento_erp
                PRIMARY KEY CLUSTERED (IdDespachoDocumentoERP),

            CONSTRAINT FK_trans_despacho_documento_erp_despacho
                FOREIGN KEY (IdDespachoEnc)
                REFERENCES dbo.trans_despacho_enc (IdDespachoEnc),

            CONSTRAINT FK_trans_despacho_documento_erp_pedido
                FOREIGN KEY (IdPedidoEnc)
                REFERENCES dbo.trans_pe_enc (IdPedidoEnc),

            CONSTRAINT CK_trans_despacho_documento_erp_tipo
                CHECK (TipoDocumentoERP IN ('ENTREGA', 'TRANSFERENCIA')),

            CONSTRAINT CK_trans_despacho_documento_erp_docentry
                CHECK (DocEntry > 0),

            CONSTRAINT CK_trans_despacho_documento_erp_docnum
                CHECK (DocNum > 0)
        );

        /* #EJC20260716_K004_DESPACHO_DOCUMENTO_ERP:
           Una misma relación puede reintentarse sin duplicar la fila. */
        CREATE UNIQUE INDEX UX_trans_despacho_documento_erp_relacion
            ON dbo.trans_despacho_documento_erp
               (IdDespachoEnc, IdPedidoEnc, CodigoEmpresaERP,
                TipoDocumentoERP, DocEntry);

        /* Un DocEntry SAP no puede pertenecer a dos pedidos WMS distintos
           dentro de la misma empresa y tipo de objeto. Esta llave convierte
           un cruce documental en error visible en vez de corrupción silenciosa. */
        CREATE UNIQUE INDEX UX_trans_despacho_documento_erp_documento_sap
            ON dbo.trans_despacho_documento_erp
               (CodigoEmpresaERP, TipoDocumentoERP, DocEntry);

        CREATE INDEX IX_trans_despacho_documento_erp_despacho
            ON dbo.trans_despacho_documento_erp
               (IdDespachoEnc, activo, TipoDocumentoERP)
            INCLUDE (IdPedidoEnc, CodigoEmpresaERP, DocEntry, DocNum, Fecha);

        CREATE INDEX IX_trans_despacho_documento_erp_pedido
            ON dbo.trans_despacho_documento_erp
               (IdPedidoEnc, activo, TipoDocumentoERP)
            INCLUDE (IdDespachoEnc, CodigoEmpresaERP, DocEntry, DocNum, Fecha);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* Validación post-despliegue: debe devolver una fila por columna definida. */
SELECT
    c.column_id,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.max_length,
    c.is_nullable
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.trans_despacho_documento_erp', N'U')
ORDER BY c.column_id;

/*
ROLLBACK MANUAL, SOLO SI LA TABLA NO TIENE DATOS ÚTILES:

IF OBJECT_ID(N'dbo.trans_despacho_documento_erp', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.trans_despacho_documento_erp)
        THROW 50001, 'Rollback detenido: trans_despacho_documento_erp contiene datos.', 1;

    DROP TABLE dbo.trans_despacho_documento_erp;
END;
*/
