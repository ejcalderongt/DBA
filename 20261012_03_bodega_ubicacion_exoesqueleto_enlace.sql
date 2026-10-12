/*
    #EJC20261012_PICKING_EXOESQUELETO
    Tramos transitables que conectan los nodos del exoesqueleto.
    Requiere ejecutar primero los scripts 01 y 02.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar bit = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto_nodo', N'U') IS NULL
        THROW 50002, 'Debe crear primero dbo.bodega_ubicacion_exoesqueleto_nodo.', 1;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto_enlace', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.bodega_ubicacion_exoesqueleto_enlace
        (
            IdVersion        bigint NOT NULL,
            IdEnlace         int NOT NULL,
            IdNodoOrigen     int NOT NULL,
            IdNodoDestino    int NOT NULL,
            Tipo             varchar(30) NOT NULL,
            Estado           varchar(20) NOT NULL,
            Grupo            nvarchar(100) NULL,
            PesoMetros       decimal(18,4) NULL,
            EsBidireccional  bit NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_enlace_bidireccional DEFAULT (1),

            CONSTRAINT PK_bodega_ubicacion_exoesqueleto_enlace
                PRIMARY KEY CLUSTERED (IdVersion, IdEnlace),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_enlace_nodos
                CHECK (IdNodoOrigen <> IdNodoDestino),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_enlace_peso
                CHECK (PesoMetros IS NULL OR PesoMetros >= 0),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_enlace_origen
                FOREIGN KEY (IdVersion, IdNodoOrigen)
                REFERENCES dbo.bodega_ubicacion_exoesqueleto_nodo (IdVersion, IdNodo),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_enlace_destino
                FOREIGN KEY (IdVersion, IdNodoDestino)
                REFERENCES dbo.bodega_ubicacion_exoesqueleto_nodo (IdVersion, IdNodo)
        );

        CREATE INDEX IX_bodega_ubicacion_exoesqueleto_enlace_destino
            ON dbo.bodega_ubicacion_exoesqueleto_enlace (IdVersion, IdNodoDestino);
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

