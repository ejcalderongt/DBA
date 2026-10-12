/*
    #EJC20261012_PICKING_EXOESQUELETO
    Relación entre una ubicación de picking y su nodo de acceso a la red.
    Requiere ejecutar primero los scripts 01 y 02.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar bit = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto_nodo', N'U') IS NULL
        THROW 50003, 'Debe crear primero dbo.bodega_ubicacion_exoesqueleto_nodo.', 1;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto_acceso', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.bodega_ubicacion_exoesqueleto_acceso
        (
            IdVersion          bigint NOT NULL,
            IdAcceso           int NOT NULL,
            IdBodega           int NOT NULL,
            IdUbicacion        int NOT NULL,
            IdNodoAcceso       int NOT NULL,
            CoordenadaX        decimal(18,4) NOT NULL,
            CoordenadaY        decimal(18,4) NOT NULL,
            Cara               varchar(20) NULL,
            Estado             varchar(20) NOT NULL,
            Confianza          decimal(5,2) NULL,
            Origen             varchar(20) NOT NULL,
            Observacion        nvarchar(250) NULL,

            CONSTRAINT PK_bodega_ubicacion_exoesqueleto_acceso
                PRIMARY KEY CLUSTERED (IdVersion, IdAcceso),
            CONSTRAINT UQ_bodega_ubicacion_exoesqueleto_acceso_ubicacion
                UNIQUE (IdVersion, IdBodega, IdUbicacion),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_acceso_coordenadas
                CHECK (CoordenadaX >= 0 AND CoordenadaY >= 0),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_acceso_confianza
                CHECK (Confianza IS NULL OR Confianza BETWEEN 0 AND 100),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_acceso_estado
                CHECK (Estado IN ('SUGERIDO', 'REVISAR', 'APROBADO', 'INVALIDO')),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_acceso_version
                FOREIGN KEY (IdVersion, IdBodega)
                REFERENCES dbo.bodega_ubicacion_exoesqueleto (IdVersion, IdBodega),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_acceso_nodo
                FOREIGN KEY (IdVersion, IdNodoAcceso)
                REFERENCES dbo.bodega_ubicacion_exoesqueleto_nodo (IdVersion, IdNodo),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_acceso_ubicacion
                FOREIGN KEY (IdUbicacion, IdBodega)
                REFERENCES dbo.bodega_ubicacion (IdUbicacion, IdBodega)
        );

        CREATE INDEX IX_bodega_ubicacion_exoesqueleto_acceso_nodo
            ON dbo.bodega_ubicacion_exoesqueleto_acceso (IdVersion, IdNodoAcceso);
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
