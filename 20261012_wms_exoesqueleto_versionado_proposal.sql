/*
    #EJC20261012_PICKING_EXOESQUELETO

    Propuesta de persistencia versionada para el exoesqueleto de bodega.

    Objetivos:
    - guardar propuestas sin sobrescribir una versión aprobada;
    - reconstruir nodos, enlaces y accesos exactamente como fueron autorizados;
    - mantener coordenadas en metros, independientes del zoom de WinForms;
    - relacionar accesos con bodega_ubicacion mediante su llave real
      (IdUbicacion, IdBodega).

    Seguridad:
    - @Aplicar = 0 ejecuta la definición dentro de una transacción y revierte;
    - cambiar a 1 solamente después de revisión y autorización de Erik/DBA;
    - este archivo no contiene migración de datos ni activa versiones.
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
            IdVersion              bigint IDENTITY(1,1) NOT NULL,
            IdBodega               int NOT NULL,
            NumeroVersion          int NOT NULL,
            Estado                 varchar(20) NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_estado DEFAULT ('BORRADOR'),
            Origen                 varchar(20) NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_origen DEFAULT ('MANUAL'),
            Descripcion            nvarchar(250) NULL,
            EscalaCuadricula       decimal(18,4) NULL,
            ParametrosJson         nvarchar(max) NULL,
            EsActual               bit NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_actual DEFAULT (0),
            UsuarioCreacion        nvarchar(50) NOT NULL,
            FechaCreacion          datetime2(0) NOT NULL
                CONSTRAINT DF_bodega_ubicacion_exoesqueleto_fecha DEFAULT (SYSDATETIME()),
            UsuarioAprobacion      nvarchar(50) NULL,
            FechaAprobacion        datetime2(0) NULL,
            MotivoAprobacion       nvarchar(500) NULL,
            VersionFila            rowversion NOT NULL,

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
                    (Estado <> 'APROBADO') OR
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

    IF OBJECT_ID(N'dbo.bodega_ubicacion_exoesqueleto_enlace', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.bodega_ubicacion_exoesqueleto_enlace
        (
            IdVersion      bigint NOT NULL,
            IdEnlace       int NOT NULL,
            IdNodoOrigen   int NOT NULL,
            IdNodoDestino  int NOT NULL,
            Tipo           varchar(30) NOT NULL,
            Estado         varchar(20) NOT NULL,
            Grupo          nvarchar(100) NULL,
            PesoMetros     decimal(18,4) NULL,
            EsBidireccional bit NOT NULL
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

    /*
        Contrato de carga propuesto:
        1. localizar la fila EsActual = 1 de la bodega;
        2. cargar nodos por IdVersion;
        3. cargar enlaces y resolver origen/destino por IdNodo;
        4. cargar accesos y relacionarlos con bodega_ubicacion;
        5. si no existe versión actual, generar la propuesta en memoria como hoy.
    */

    IF @Aplicar = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Estructura de exoesqueleto aplicada.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'DRY RUN: estructura validada y revertida. Para aplicar requiere autorización y @Aplicar = 1.';
    END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
