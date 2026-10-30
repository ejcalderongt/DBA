/*
    #EJC20261029_PICKING_CONFIG_SEED
    Tres perfiles experimentales para madurar la asignación de picking en MH05.
    Destino explícito: TOMWMS_MHS_DEV, IdBodega=5, Codigo=MH05.
    @Aplicar=0 valida y revierte; @Aplicar=1 confirma la inserción autorizada.
    Todos se crean BORRADOR/PROPUESTA; no se activan ni se alteran tareas.
    Se omiten nombres ya existentes, incluso vigentes o modificados por el usuario.
    La repetición no duplica perfiles mientras conserven su nombre; si se renombran,
    se consideran perfiles distintos. No se sobrescriben parámetros existentes.
    El bloqueo de bodega sigue el orden usado por clsLnConfiguracion_picking_op.
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
DECLARE @BaseEsperada sysname = N'TOMWMS_MHS_DEV';
DECLARE @IdBodega int = 5;
DECLARE @CodigoBodega nvarchar(50) = N'MH05';
DECLARE @Usuario nvarchar(50) = N'EJC_SEED';

IF DB_NAME() <> @BaseEsperada
    THROW 51010, N'La base seleccionada no corresponde al destino autorizado.', 1;
IF @@TRANCOUNT <> 0
    THROW 51011, N'Ejecutar sin una transacción externa abierta.', 1;
IF OBJECT_ID(N'dbo.configuracion_picking_op', N'U') IS NULL
    THROW 51012, N'Primero instalar dbo.configuracion_picking_op.', 1;

DECLARE @Perfiles TABLE
(
    Orden int PRIMARY KEY,
    Nombre nvarchar(100) NOT NULL,
    Descripcion nvarchar(500) NOT NULL,
    Criterio nvarchar(25) NOT NULL,
    Agrupacion nvarchar(15) NOT NULL,
    MaxLineas int NOT NULL,
    MaxUbicaciones int NOT NULL,
    MaxPendientes int NOT NULL,
    PesoLineas decimal(9,4) NOT NULL,
    PesoUbicaciones decimal(9,4) NOT NULL
);

INSERT @Perfiles VALUES
    (1, N'BASE 01 - Conservador por líneas',
     N'Paquetes pequeños por tramo. Una cola pendiente y un paquete en ejecución. Línea base para observar aceptación y tiempos.',
     N'LINEAS', N'TRAMO', 15, 8, 1, 1, 1),
    (2, N'BASE 02 - Zona preferida y ubicaciones',
     N'Agrupa por zona y balancea por ubicaciones distintas. Permite dos paquetes pendientes. La zona es preferida, no una exclusión obligatoria.',
     N'UBICACIONES', N'ZONA', 25, 12, 2, 1, 1),
    (3, N'BASE 03 - Balance ponderado',
     N'Agrupa por tramo y combina líneas con ubicaciones distintas. Peso de líneas=1 y de ubicaciones=2. Hipótesis experimental, no rendimiento observado.',
     N'CARGA_PONDERADA', N'TRAMO', 20, 10, 2, 1, 2);

DECLARE @Resultado TABLE
(
    Orden int,
    Accion nvarchar(20),
    IdConfiguracionPickingOp bigint,
    NumeroVersion int,
    Nombre nvarchar(100),
    Estado nvarchar(12)
);

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.bodega WITH (UPDLOCK,HOLDLOCK)
        WHERE IdBodega=@IdBodega AND Codigo=@CodigoBodega AND Activo=1
    )
        THROW 51013, N'La bodega activa no coincide con el ID y código esperados.', 1;

    DECLARE @Orden int = 1, @Nombre nvarchar(100), @IdExistente bigint;
    DECLARE @NumeroVersion int;
    WHILE @Orden <= 3
    BEGIN
        SELECT @Nombre=Nombre FROM @Perfiles WHERE Orden=@Orden;
        SET @IdExistente=NULL;

        IF (SELECT COUNT(*) FROM dbo.configuracion_picking_op WITH (UPDLOCK,HOLDLOCK)
            WHERE IdBodega=@IdBodega AND Nombre=@Nombre) > 1
            THROW 51014, N'Hay perfiles duplicados por nombre. Revisar antes de continuar.', 1;

        SELECT @IdExistente=IdConfiguracionPickingOp
        FROM dbo.configuracion_picking_op WITH (UPDLOCK,HOLDLOCK)
        WHERE IdBodega=@IdBodega AND Nombre=@Nombre;

        IF @IdExistente IS NOT NULL
        BEGIN
            INSERT @Resultado
            SELECT @Orden,N'CONSERVADO',IdConfiguracionPickingOp,NumeroVersion,Nombre,Estado
            FROM dbo.configuracion_picking_op WHERE IdConfiguracionPickingOp=@IdExistente;
        END
        ELSE
        BEGIN
            SELECT @NumeroVersion=ISNULL(MAX(NumeroVersion),0)+1
            FROM dbo.configuracion_picking_op WITH (UPDLOCK,HOLDLOCK)
            WHERE IdBodega=@IdBodega;

            INSERT dbo.configuracion_picking_op
            (
                IdBodega,NumeroVersion,Nombre,Descripcion,Estado,ModoAsignacion,
                CriterioBalanceo,AgrupacionPaquete,MaxLineasPaquete,MaxUbicacionesPaquete,
                MaxPaquetesPendientesOperador,MaxPaquetesEnEjecucionOperador,PoliticaZona,
                ExigirDisponibilidadConfirmada,AplicarJornadaLaboral,PriorizarUrgencia,
                PriorizarAntiguedad,PesoLineasPendientes,PesoUbicacionesPendientes,
                RequerirAceptacion,TiempoAceptacionMinutos,ReasignarSinAceptacion,
                UsarDistanciaRecorrido,user_agr,MotivoCambio
            )
            OUTPUT @Orden,N'INSERTADO',INSERTED.IdConfiguracionPickingOp,
                   INSERTED.NumeroVersion,INSERTED.Nombre,INSERTED.Estado INTO @Resultado
            SELECT @IdBodega,@NumeroVersion,Nombre,Descripcion,N'BORRADOR',N'PROPUESTA',
                   Criterio,Agrupacion,MaxLineas,MaxUbicaciones,MaxPendientes,1,N'PREFERIDA',
                   1,1,1,1,PesoLineas,PesoUbicaciones,1,5,0,0,@Usuario,
                   N'#EJC20261029_PICKING_CONFIG_SEED: perfil inicial experimental; validar por simulación antes de activar.'
            FROM @Perfiles WHERE Orden=@Orden;
        END;

        SET @Orden+=1;
    END;

    IF @Aplicar=1
        COMMIT TRANSACTION;
    ELSE
        ROLLBACK TRANSACTION;

    SELECT DB_NAME() AS BaseDatos,@IdBodega AS IdBodega,@CodigoBodega AS CodigoBodega,
           CASE WHEN @Aplicar=1 THEN N'APLICADO' ELSE N'DRY_RUN_REVERTIDO' END AS Modo,
           Accion,IdConfiguracionPickingOp,NumeroVersion,Nombre,Estado
    FROM @Resultado ORDER BY Orden;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
