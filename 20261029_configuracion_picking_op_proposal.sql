/*
    #EJC20261029_PICKING_CONFIG
    Propuesta para revisión: configuración versionada de asignación por bodega.
    Ejecutar en la base seleccionada explícitamente en SSMS. No contiene USE.
    @Aplicar=0: validar DDL y revertir. @Aplicar=1: crear tras aprobación.
    No crea configuraciones ni habilita asignación automática.

    DAL futuro: guardar borradores usando VersionFila; clonar versiones vigentes;
    activar en transacción serializable, pasando la vigente anterior a HISTORICO.
    NumeroVersion se calcula bajo bloqueo por bodega, nunca MAX+1 sin protección.
    Cada asignación futura conservará IdConfiguracionPickingOp.
    Disponibilidad, equipo y estado de tareas no se almacenan en esta tabla.
    Los valores DEFAULT son iniciales experimentales para simulación.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar bit = 0;

IF @@TRANCOUNT <> 0
    THROW 51000, N'Ejecutar sin una transacción externa abierta.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.configuracion_picking_op', N'U') IS NOT NULL
        THROW 51001, N'La tabla ya existe. Revisar su contrato; no se modifica ni se omite silenciosamente.', 1;

    IF OBJECT_ID(N'dbo.bodega', N'U') IS NULL
        THROW 51002, N'No existe dbo.bodega en la base seleccionada.', 1;

    CREATE TABLE dbo.configuracion_picking_op
    (
        IdConfiguracionPickingOp bigint IDENTITY(1,1) NOT NULL,
        IdBodega int NOT NULL,
        NumeroVersion int NOT NULL,
        Nombre nvarchar(100) NOT NULL,
        Descripcion nvarchar(500) NULL,
        Estado nvarchar(12) NOT NULL
            CONSTRAINT DF_config_picking_op_estado DEFAULT (N'BORRADOR'),

        ModoAsignacion nvarchar(12) NOT NULL
            CONSTRAINT DF_config_picking_op_modo DEFAULT (N'PROPUESTA'),
        CriterioBalanceo nvarchar(25) NOT NULL
            CONSTRAINT DF_config_picking_op_balance DEFAULT (N'LINEAS'),
        AgrupacionPaquete nvarchar(15) NOT NULL
            CONSTRAINT DF_config_picking_op_agrupacion DEFAULT (N'TRAMO'),
        MaxLineasPaquete int NOT NULL
            CONSTRAINT DF_config_picking_op_lineas DEFAULT (20),
        MaxUbicacionesPaquete int NOT NULL
            CONSTRAINT DF_config_picking_op_ubicaciones DEFAULT (10),
        MaxPaquetesPendientesOperador int NOT NULL
            CONSTRAINT DF_config_picking_op_pendientes DEFAULT (1),
        MaxPaquetesEnEjecucionOperador int NOT NULL
            CONSTRAINT DF_config_picking_op_ejecucion DEFAULT (1),
        PoliticaZona nvarchar(15) NOT NULL
            CONSTRAINT DF_config_picking_op_zona DEFAULT (N'PREFERIDA'),
        ExigirDisponibilidadConfirmada bit NOT NULL
            CONSTRAINT DF_config_picking_op_disponibilidad DEFAULT (1),
        AplicarJornadaLaboral bit NOT NULL
            CONSTRAINT DF_config_picking_op_jornada DEFAULT (1),
        PriorizarUrgencia bit NOT NULL
            CONSTRAINT DF_config_picking_op_urgencia DEFAULT (1),
        PriorizarAntiguedad bit NOT NULL
            CONSTRAINT DF_config_picking_op_antiguedad DEFAULT (1),
        PesoLineasPendientes decimal(9,4) NOT NULL
            CONSTRAINT DF_config_picking_op_peso_lineas DEFAULT (1),
        PesoUbicacionesPendientes decimal(9,4) NOT NULL
            CONSTRAINT DF_config_picking_op_peso_ubicaciones DEFAULT (1),
        RequerirAceptacion bit NOT NULL
            CONSTRAINT DF_config_picking_op_aceptacion DEFAULT (1),
        TiempoAceptacionMinutos int NULL
            CONSTRAINT DF_config_picking_op_tiempo DEFAULT (5),
        ReasignarSinAceptacion bit NOT NULL
            CONSTRAINT DF_config_picking_op_reasignar DEFAULT (0),
        UsarDistanciaRecorrido bit NOT NULL
            CONSTRAINT DF_config_picking_op_distancia DEFAULT (0),

        user_agr nvarchar(50) NOT NULL,
        fec_agr datetime2(0) NOT NULL
            CONSTRAINT DF_config_picking_op_fecha DEFAULT (SYSDATETIME()),
        user_mod nvarchar(50) NULL,
        fec_mod datetime2(0) NULL,
        UsuarioActivacion nvarchar(50) NULL,
        FechaActivacion datetime2(0) NULL,
        MotivoCambio nvarchar(500) NOT NULL,
        VersionFila rowversion NOT NULL,

        CONSTRAINT PK_configuracion_picking_op PRIMARY KEY CLUSTERED (IdConfiguracionPickingOp),
        CONSTRAINT UQ_config_picking_op_bodega_version UNIQUE (IdBodega, NumeroVersion),
        CONSTRAINT FK_config_picking_op_bodega FOREIGN KEY (IdBodega) REFERENCES dbo.bodega(IdBodega),
        CONSTRAINT CK_config_picking_op_version CHECK (NumeroVersion > 0),
        CONSTRAINT CK_config_picking_op_estado CHECK (Estado IN (N'BORRADOR', N'VIGENTE', N'HISTORICO')),
        CONSTRAINT CK_config_picking_op_modo CHECK (ModoAsignacion IN (N'MANUAL', N'PROPUESTA', N'AUTOMATICO')),
        CONSTRAINT CK_config_picking_op_balance CHECK (CriterioBalanceo IN (N'LINEAS', N'UBICACIONES', N'CARGA_PONDERADA')),
        CONSTRAINT CK_config_picking_op_agrupacion CHECK (AgrupacionPaquete IN (N'PEDIDO', N'ZONA', N'TRAMO')),
        CONSTRAINT CK_config_picking_op_zona CHECK (PoliticaZona IN (N'SIN_RESTRICCION', N'PREFERIDA', N'EXCLUSIVA')),
        CONSTRAINT CK_config_picking_op_limites CHECK
            (MaxLineasPaquete > 0 AND MaxUbicacionesPaquete > 0
             AND MaxPaquetesPendientesOperador > 0 AND MaxPaquetesEnEjecucionOperador > 0),
        CONSTRAINT CK_config_picking_op_pesos CHECK
            (PesoLineasPendientes >= 0 AND PesoUbicacionesPendientes >= 0
             AND (CriterioBalanceo <> N'CARGA_PONDERADA'
                  OR PesoLineasPendientes > 0 OR PesoUbicacionesPendientes > 0)),
        CONSTRAINT CK_config_picking_op_aceptacion CHECK
            ((RequerirAceptacion = 0 AND TiempoAceptacionMinutos IS NULL AND ReasignarSinAceptacion = 0)
             OR (RequerirAceptacion = 1 AND TiempoAceptacionMinutos IS NOT NULL AND TiempoAceptacionMinutos > 0)),
        CONSTRAINT CK_config_picking_op_textos CHECK
            (LEN(LTRIM(RTRIM(Nombre))) > 0 AND LEN(LTRIM(RTRIM(user_agr))) > 0
             AND LEN(LTRIM(RTRIM(MotivoCambio))) > 0),
        CONSTRAINT CK_config_picking_op_modificacion CHECK
            ((user_mod IS NULL AND fec_mod IS NULL)
             OR (user_mod IS NOT NULL AND fec_mod IS NOT NULL AND LEN(LTRIM(RTRIM(user_mod))) > 0)),
        CONSTRAINT CK_config_picking_op_activacion CHECK
            ((Estado = N'BORRADOR' AND UsuarioActivacion IS NULL AND FechaActivacion IS NULL)
             OR (Estado IN (N'VIGENTE', N'HISTORICO') AND UsuarioActivacion IS NOT NULL
                 AND LEN(LTRIM(RTRIM(UsuarioActivacion))) > 0 AND FechaActivacion IS NOT NULL))
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_config_picking_op_vigente
        ON dbo.configuracion_picking_op(IdBodega)
        WHERE Estado = N'VIGENTE';

    IF @Aplicar = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT N'Aplicado: dbo.configuracion_picking_op. Sin datos ni activación automática.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT N'DRY RUN correcto: DDL validado y revertido. Pendiente aprobación para aplicar.';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
