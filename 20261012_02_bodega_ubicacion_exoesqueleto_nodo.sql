/*
    #EJC20261012_PICKING_EXOESQUELETO
    Puntos cartesianos transitables de cada versión del exoesqueleto.
    Requiere ejecutar primero 20261012_01_bodega_ubicacion_exoesqueleto.sql.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar bit = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto', N'U') IS NULL
        THROW 50001, 'Debe crear primero dbo.bodega_ubicacion_exoesqueleto.', 1;

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto_nodo', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.bodega_ubicacion_exoesqueleto_nodo
        (
            IdVersion      bigint NOT NULL,
            IdNodo         int NOT NULL,
            CoordenadaX    decimal(18,4) NOT NULL,
            CoordenadaY    decimal(18,4) NOT NULL,
            Tipo           varchar(30) NOT NULL,
            Estado         varchar(20) NOT NULL,

            CONSTRAINT PK_bodega_ubicacion_exoesqueleto_nodo
                PRIMARY KEY CLUSTERED (IdVersion, IdNodo),
            CONSTRAINT CK_bodega_ubicacion_exoesqueleto_nodo_coordenadas
                CHECK (CoordenadaX >= 0 AND CoordenadaY >= 0),
            CONSTRAINT FK_bodega_ubicacion_exoesqueleto_nodo_version
                FOREIGN KEY (IdVersion)
                REFERENCES dbo.bodega_ubicacion_exoesqueleto (IdVersion)
        );
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
