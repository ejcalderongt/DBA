/*
    #EJC20260728_TRANS_LICENCIA_EMPAQUE

    Catálogo y ciclo de vida de licencias maestras de empaque.

    Contrato:
    - Una fila representa una licencia maestra de packing.
    - El contenido no se duplica en esta estructura.
    - dbo.trans_packing_enc conserva el detalle operativo.
    - La asociación natural es:
          trans_licencia_empaque.LicPlate = trans_packing_enc.no_linea
    - dbo.i_nav_barras_pallet podrá recibir posteriormente la proyección del
      packing finalizado para el flujo de recepción en la bodega destino.
    - No modifica pedido, stock, reserva, picking, packing ni recepción.

    Estados:
    GENERADA   : licencia creada o preimpresa, todavía sin packing asociado.
    ASOCIADA   : licencia ocupada por al menos una línea de packing.
    DESPACHADA : licencia enviada desde la bodega actual.
    RECIBIDA   : licencia recibida en la bodega destino.
    ANULADA    : licencia invalidada.

    Migración del primer borrador:
    - Retira trans_licencia_empaque_enc y trans_licencia_empaque_det únicamente
      cuando ambas están vacías.
    - Si alguna contiene datos, aborta para evitar pérdida de información.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.trans_licencia_empaque', N'U') IS NULL
       AND
       (
           OBJECT_ID(N'dbo.trans_licencia_empaque_enc', N'U') IS NOT NULL
           OR OBJECT_ID(N'dbo.trans_licencia_empaque_det', N'U') IS NOT NULL
       )
    BEGIN
        DECLARE @FilasEnc bigint = 0;
        DECLARE @FilasDet bigint = 0;

        IF OBJECT_ID(N'dbo.trans_licencia_empaque_enc', N'U') IS NOT NULL
            SELECT @FilasEnc = COUNT_BIG(*)
            FROM dbo.trans_licencia_empaque_enc;

        IF OBJECT_ID(N'dbo.trans_licencia_empaque_det', N'U') IS NOT NULL
            SELECT @FilasDet = COUNT_BIG(*)
            FROM dbo.trans_licencia_empaque_det;

        IF @FilasEnc > 0 OR @FilasDet > 0
            THROW 51000,
                  'No se puede reemplazar el modelo anterior de licencia de empaque porque contiene datos.',
                  1;

        DROP TABLE IF EXISTS dbo.trans_licencia_empaque_det;
        DROP TABLE IF EXISTS dbo.trans_licencia_empaque_enc;
    END;

    IF OBJECT_ID(N'dbo.trans_licencia_empaque', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.trans_licencia_empaque
        (
            IdLicenciaEmpaque       int IDENTITY(1,1) NOT NULL,
            LicPlate                nvarchar(50) NOT NULL,

            IdBodega                int NOT NULL,
            IdBodegaDestino         int NULL,
            IdPropietario           int NULL,

            TipoOrigen              varchar(20) NOT NULL
                CONSTRAINT DF_trans_lic_emp_tipo_origen DEFAULT ('MANUAL'),
            IdDocumento             bigint NULL,
            ReferenciaDocumento     nvarchar(50) NULL,

            Estado                  varchar(20) NOT NULL
                CONSTRAINT DF_trans_lic_emp_estado DEFAULT ('GENERADA'),

            FechaGeneracion         datetime NOT NULL
                CONSTRAINT DF_trans_lic_emp_fecha_generacion DEFAULT (GETDATE()),
            FechaAsociacion         datetime NULL,
            FechaDespacho           datetime NULL,
            FechaRecepcion          datetime NULL,
            FechaAnulacion          datetime NULL,

            FechaPrimeraImpresion   datetime NULL,
            FechaUltimaImpresion    datetime NULL,
            CantidadImpresiones     int NOT NULL
                CONSTRAINT DF_trans_lic_emp_cantidad_impresiones DEFAULT (0),
            UsuarioUltimaImpresion  nvarchar(50) NULL,

            Observacion             nvarchar(250) NULL,
            MotivoAnulacion         nvarchar(250) NULL,

            Activo                  bit NOT NULL
                CONSTRAINT DF_trans_lic_emp_activo DEFAULT (1),
            user_agr                nvarchar(50) NOT NULL,
            fec_agr                 datetime NOT NULL
                CONSTRAINT DF_trans_lic_emp_fec_agr DEFAULT (GETDATE()),
            user_mod                nvarchar(50) NULL,
            fec_mod                 datetime NULL,

            VersionFila             rowversion NOT NULL,

            CONSTRAINT PK_trans_licencia_empaque
                PRIMARY KEY CLUSTERED (IdLicenciaEmpaque),

            CONSTRAINT UQ_trans_licencia_empaque_LicPlate
                UNIQUE (LicPlate),

            CONSTRAINT CK_trans_lic_emp_tipo_origen
                CHECK
                (
                    TipoOrigen IN
                    (
                        'MANUAL',
                        'PEDIDO',
                        'TRANSFERENCIA',
                        'EXPLOSION'
                    )
                ),

            CONSTRAINT CK_trans_lic_emp_estado
                CHECK
                (
                    Estado IN
                    (
                        'GENERADA',
                        'ASOCIADA',
                        'DESPACHADA',
                        'RECIBIDA',
                        'ANULADA'
                    )
                ),

            CONSTRAINT CK_trans_lic_emp_bodegas
                CHECK
                (
                    IdBodegaDestino IS NULL
                    OR IdBodegaDestino <> IdBodega
                ),

            CONSTRAINT CK_trans_lic_emp_fechas_estado
                CHECK
                (
                    (Estado <> 'ASOCIADA' OR FechaAsociacion IS NOT NULL)
                    AND (Estado <> 'DESPACHADA' OR FechaDespacho IS NOT NULL)
                    AND (Estado <> 'RECIBIDA' OR FechaRecepcion IS NOT NULL)
                    AND (Estado <> 'ANULADA' OR FechaAnulacion IS NOT NULL)
                ),

            CONSTRAINT CK_trans_lic_emp_impresiones
                CHECK
                (
                    CantidadImpresiones >= 0
                    AND
                    (
                        (
                            CantidadImpresiones = 0
                            AND FechaPrimeraImpresion IS NULL
                            AND FechaUltimaImpresion IS NULL
                        )
                        OR
                        (
                            CantidadImpresiones > 0
                            AND FechaPrimeraImpresion IS NOT NULL
                            AND FechaUltimaImpresion IS NOT NULL
                            AND FechaUltimaImpresion >= FechaPrimeraImpresion
                        )
                    )
                )
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque')
          AND name = N'IX_trans_lic_emp_bodega_estado'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_bodega_estado
            ON dbo.trans_licencia_empaque
            (
                IdBodega,
                Estado,
                Activo
            )
            INCLUDE
            (
                LicPlate,
                IdBodegaDestino,
                ReferenciaDocumento,
                FechaGeneracion,
                CantidadImpresiones
            );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque')
          AND name = N'IX_trans_lic_emp_documento'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_documento
            ON dbo.trans_licencia_empaque
            (
                TipoOrigen,
                IdDocumento
            )
            INCLUDE
            (
                LicPlate,
                Estado,
                IdBodega,
                ReferenciaDocumento,
                CantidadImpresiones
            );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque')
          AND name = N'IX_trans_lic_emp_pendiente_impresion'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_pendiente_impresion
            ON dbo.trans_licencia_empaque
            (
                IdBodega,
                FechaGeneracion
            )
            INCLUDE
            (
                LicPlate,
                TipoOrigen,
                IdDocumento,
                ReferenciaDocumento
            )
            WHERE Activo = 1
              AND CantidadImpresiones = 0;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Validación post-despliegue. No modifica datos.
SELECT
    t.name AS Tabla,
    i.name AS Indice,
    i.is_unique AS EsUnico,
    i.is_primary_key AS EsLlavePrimaria,
    i.has_filter AS EsFiltrado,
    i.filter_definition AS Filtro
FROM sys.tables AS t
LEFT JOIN sys.indexes AS i
    ON i.object_id = t.object_id
   AND i.index_id > 0
WHERE t.object_id = OBJECT_ID(N'dbo.trans_licencia_empaque')
ORDER BY i.index_id;
GO

/*
    Rollback manual, únicamente antes de que la tabla entre en operación:

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS dbo.trans_licencia_empaque;
    COMMIT TRANSACTION;
*/
