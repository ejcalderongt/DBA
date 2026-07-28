/*
    #EJC20260728_TRANS_LICENCIA_EMPAQUE

    Modelo independiente para licencias de empaque homogéneas o mixtas.

    Alcance:
    - No modifica tablas de pedido, stock, reserva, picking, packing o recepción.
    - La cabecera identifica la licencia y su ciclo operativo.
    - El detalle conserva un snapshot legible y transportable de su contenido.
    - Las cantidades operativas se almacenan en UMBAS usando float, de acuerdo
      con stock.cantidad, stock_res.cantidad y trans_movimientos.cantidad.
    - Los identificadores locales son auxiliares. CodigoProducto, NombreProducto,
      lote, vencimiento y unidad de medida conservan la lectura histórica.

    Estados:
    GENERADA   : licencia creada o preimpresa, todavía sin contenido confirmado.
    ASOCIADA   : contenido confirmado y asociado operativamente a la licencia.
    DESPACHADA : licencia enviada desde la bodega actual.
    RECIBIDA   : licencia recibida en la bodega destino.
    ANULADA    : licencia invalidada antes de completar el flujo.

    Ejecutar primero en QA.
    Este script no ha sido ejecutado por Codex en ninguna base de datos.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.trans_licencia_empaque_enc', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.trans_licencia_empaque_enc
        (
            IdLicenciaEmpaque  int IDENTITY(1,1) NOT NULL,
            LicPlate           nvarchar(50) NOT NULL,

            -- Bodega propietaria de la licencia y destino previsto, si aplica.
            IdBodega           int NOT NULL,
            IdBodegaDestino    int NULL,
            IdPropietario      int NULL,

            -- Referencia desacoplada del tipo de documento operativo.
            TipoOrigen         varchar(20) NOT NULL
                CONSTRAINT DF_trans_lic_emp_enc_tipo_origen DEFAULT ('MANUAL'),
            IdDocumento        bigint NULL,
            ReferenciaDocumento nvarchar(50) NULL,

            Estado             varchar(20) NOT NULL
                CONSTRAINT DF_trans_lic_emp_enc_estado DEFAULT ('GENERADA'),

            FechaGeneracion    datetime NOT NULL
                CONSTRAINT DF_trans_lic_emp_enc_fecha_generacion DEFAULT (GETDATE()),
            FechaAsociacion    datetime NULL,
            FechaDespacho      datetime NULL,
            FechaRecepcion     datetime NULL,
            FechaAnulacion     datetime NULL,

            Observacion        nvarchar(250) NULL,
            MotivoAnulacion    nvarchar(250) NULL,

            Activo             bit NOT NULL
                CONSTRAINT DF_trans_lic_emp_enc_activo DEFAULT (1),
            user_agr           nvarchar(50) NOT NULL,
            fec_agr            datetime NOT NULL
                CONSTRAINT DF_trans_lic_emp_enc_fec_agr DEFAULT (GETDATE()),
            user_mod           nvarchar(50) NULL,
            fec_mod            datetime NULL,

            VersionFila        rowversion NOT NULL,

            CONSTRAINT PK_trans_licencia_empaque_enc
                PRIMARY KEY CLUSTERED (IdLicenciaEmpaque),

            -- Las nuevas licencias de empaque deben poder resolverse por escaneo
            -- sin depender de la bodega en la que se originaron.
            CONSTRAINT UQ_trans_licencia_empaque_enc_LicPlate
                UNIQUE (LicPlate),

            CONSTRAINT CK_trans_lic_emp_enc_tipo_origen
                CHECK (TipoOrigen IN
                (
                    'MANUAL',
                    'PEDIDO',
                    'TRANSFERENCIA',
                    'EXPLOSION'
                )),

            CONSTRAINT CK_trans_lic_emp_enc_estado
                CHECK (Estado IN
                (
                    'GENERADA',
                    'ASOCIADA',
                    'DESPACHADA',
                    'RECIBIDA',
                    'ANULADA'
                )),

            CONSTRAINT CK_trans_lic_emp_enc_bodegas
                CHECK (IdBodegaDestino IS NULL OR IdBodegaDestino <> IdBodega),

            CONSTRAINT CK_trans_lic_emp_enc_fechas_estado
                CHECK
                (
                    (Estado <> 'ASOCIADA' OR FechaAsociacion IS NOT NULL)
                    AND (Estado <> 'DESPACHADA' OR FechaDespacho IS NOT NULL)
                    AND (Estado <> 'RECIBIDA' OR FechaRecepcion IS NOT NULL)
                    AND (Estado <> 'ANULADA' OR FechaAnulacion IS NOT NULL)
                )
        );
    END;

    IF OBJECT_ID(N'dbo.trans_licencia_empaque_det', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.trans_licencia_empaque_det
        (
            IdLicenciaEmpaqueDet int IDENTITY(1,1) NOT NULL,
            IdLicenciaEmpaque    int NOT NULL,
            NoLinea              int NOT NULL,

            -- Referencias técnicas locales. No constituyen el contrato para
            -- recepción en otra bodega o en otra instalación WMS.
            IdProducto           int NULL,
            IdProductoBodega     int NULL,
            IdProductoTallaColor int NULL,

            -- Snapshot funcional, legible y transportable.
            CodigoProducto       nvarchar(50) NOT NULL,
            NombreProducto       nvarchar(150) NOT NULL,

            IdUnidadMedida       int NULL,
            CodigoUnidadMedida   nvarchar(25) NULL,
            NombreUnidadMedida   nvarchar(50) NULL,

            IdProductoEstado     int NULL,
            NombreEstado         nvarchar(50) NULL,

            IdPresentacion       int NULL,
            NombrePresentacion   nvarchar(50) NULL,

            Lote                 nvarchar(50) NULL,
            FechaVence           datetime NULL,
            FechaManufactura     datetime NULL,
            Serial               nvarchar(50) NULL,

            CantidadUMBas        float NOT NULL,

            -- Permanecen NULL para productos sin manejo de peso.
            PesoNeto             float NULL,
            PesoBruto            float NULL,
            Tara                 float NULL,

            Activo               bit NOT NULL
                CONSTRAINT DF_trans_lic_emp_det_activo DEFAULT (1),
            user_agr             nvarchar(50) NOT NULL,
            fec_agr              datetime NOT NULL
                CONSTRAINT DF_trans_lic_emp_det_fec_agr DEFAULT (GETDATE()),
            user_mod             nvarchar(50) NULL,
            fec_mod              datetime NULL,

            VersionFila          rowversion NOT NULL,

            CONSTRAINT PK_trans_licencia_empaque_det
                PRIMARY KEY CLUSTERED (IdLicenciaEmpaqueDet),

            CONSTRAINT FK_trans_licencia_empaque_det_enc
                FOREIGN KEY (IdLicenciaEmpaque)
                REFERENCES dbo.trans_licencia_empaque_enc (IdLicenciaEmpaque),

            CONSTRAINT UQ_trans_licencia_empaque_det_linea
                UNIQUE (IdLicenciaEmpaque, NoLinea),

            CONSTRAINT CK_trans_lic_emp_det_no_linea
                CHECK (NoLinea > 0),

            CONSTRAINT CK_trans_lic_emp_det_cantidad
                CHECK (CantidadUMBas > 0),

            CONSTRAINT CK_trans_lic_emp_det_pesos
                CHECK
                (
                    (PesoNeto IS NULL OR PesoNeto >= 0)
                    AND (PesoBruto IS NULL OR PesoBruto >= 0)
                    AND (Tara IS NULL OR Tara >= 0)
                    AND
                    (
                        PesoNeto IS NULL
                        OR PesoBruto IS NULL
                        OR PesoBruto >= PesoNeto
                    )
                )
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque_enc')
          AND name = N'IX_trans_lic_emp_enc_bodega_estado'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_enc_bodega_estado
            ON dbo.trans_licencia_empaque_enc
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
                FechaGeneracion
            );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque_enc')
          AND name = N'IX_trans_lic_emp_enc_documento'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_enc_documento
            ON dbo.trans_licencia_empaque_enc
            (
                TipoOrigen,
                IdDocumento
            )
            INCLUDE
            (
                LicPlate,
                Estado,
                IdBodega,
                ReferenciaDocumento
            );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque_det')
          AND name = N'IX_trans_lic_emp_det_producto_lote'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_det_producto_lote
            ON dbo.trans_licencia_empaque_det
            (
                CodigoProducto,
                Lote
            )
            INCLUDE
            (
                IdLicenciaEmpaque,
                CantidadUMBas,
                FechaVence,
                PesoNeto,
                PesoBruto
            );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.trans_licencia_empaque_det')
          AND name = N'IX_trans_lic_emp_det_licencia_activo'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_trans_lic_emp_det_licencia_activo
            ON dbo.trans_licencia_empaque_det
            (
                IdLicenciaEmpaque,
                Activo
            )
            INCLUDE
            (
                NoLinea,
                CodigoProducto,
                NombreProducto,
                Lote,
                FechaVence,
                CantidadUMBas,
                PesoNeto
            );
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
    i.is_primary_key AS EsLlavePrimaria
FROM sys.tables AS t
LEFT JOIN sys.indexes AS i
    ON i.object_id = t.object_id
   AND i.index_id > 0
WHERE t.object_id IN
(
    OBJECT_ID(N'dbo.trans_licencia_empaque_enc'),
    OBJECT_ID(N'dbo.trans_licencia_empaque_det')
)
ORDER BY t.name, i.index_id;
GO

/*
    Rollback manual, únicamente antes de que las tablas entren en operación:

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS dbo.trans_licencia_empaque_det;
    DROP TABLE IF EXISTS dbo.trans_licencia_empaque_enc;
    COMMIT TRANSACTION;
*/
