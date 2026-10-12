/*
    #EJC20261012_PICKING_EXOESQUELETO
    Cabecera versionada y autorizable del exoesqueleto de una bodega.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar bit = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.bodega_ubicacion_exoesqueleto
        (
            IdVersion            bigint IDENTITY(1,1) NOT NULL,
            IdBodega             int NOT NULL,
            NumeroVersion        int NOT NULL,
            Estado               varchar(20) NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_estado DEFAULT ('BORRADOR'),
            Origen               varchar(20) NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_origen DEFAULT ('MANUAL'),
            Descripcion          nvarchar(250) NULL,
            EscalaCuadricula     decimal(18,4) NULL,
            ParametrosJson       nvarchar(max) NULL,
            EsActual             bit NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_actual DEFAULT (0),
            UsuarioCreacion      nvarchar(50) NOT NULL,
            FechaCreacion        datetime2(0) NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_fecha DEFAULT (SYSDATETIME()),
            UsuarioAprobacion    nvarchar(50) NULL,
            FechaAprobacion      datetime2(0) NULL,
            MotivoAprobacion     nvarchar(500) NULL,
            VersionFila          rowversion NOT NULL,

            CONSTRAINT PK_bodega_ubicacion_exoesqueleto
                PRIMARY KEY CLUSTERED (IdVersion),
            CONSTRAINT UQ_bodega_ubicacion_exoesqueleto_bodega_numero
                UNIQUE (IdBodega, NumeroVersion),
            CONSTRAINT UQ_bodega_ubicacion_exoesqueleto_id_bodega
                UNIQUE (IdVersion, IdBodega),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_estado
                CHECK (Estado IN ('BORRADOR', 'APROBADO', 'INACTIVO')),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_escala
                CHECK (EscalaCuadricula IS NULL OR EscalaCuadricula > 0),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_aprobacion
                CHECK (
                    Estado <> 'APROBADO' OR
                    (UsuarioAprobacion IS NOT NULL AND FechaAprobacion IS NOT NULL)
                ),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_actual
                CHECK (EsActual = 0 OR Estado = 'APROBADO'),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_bodega
                FOREIGN KEY (IdBodega) REFERENCES dbo.bodega (IdBodega)
        );

        CREATE UNIQUE INDEX UX_bodega_ubicacion_exoesqueleto_actual
            ON dbo.bodega_ubicacion_exoesqueleto (IdBodega)
            WHERE EsActual = 1;
    END;

    IF @Aplicar = 1
        COMMIT TRANSACTION;
    ELSE
        ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
