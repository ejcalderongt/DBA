/*
    #EJC20261029_PICKING_CONFIG_MENU
    Mantenimientos > Bodega > Configuración de asignación de picking.
    nombre_lgco coincide con el BarButtonItem mnuConfiguracionPickingOp de BOF.
    Instalar primero 20261029_configuracion_picking_op_proposal.sql si falta.
    Hereda consulta/modificación de mnuMantOperadores. No concede eliminación.
    Conserva permisos explícitos que ya existan para esta opción, incluidos denegados.
    Cambiar destino explícitamente para copias locales; no usar en producción remota.
    @Aplicar=0 valida/revierte; @Aplicar=1 confirma con autorización.
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

DECLARE @Aplicar bit=0;
DECLARE @BaseEsperada sysname=N'TOMWMS_MHS_DEV';
DECLARE @MaquinaEsperada sysname=N'MHS-APP-QA';
DECLARE @Usuario nvarchar(25)=N'EJC_CONFIG_PICKING';
DECLARE @NombreMenu nvarchar(50)=N'mnuConfiguracionPickingOp';

IF DB_NAME()<>@BaseEsperada OR ISNULL(CONVERT(nvarchar(128),SERVERPROPERTY('MachineName')),N'')<>@MaquinaEsperada
    THROW 51100,N'La base o máquina no corresponde al destino autorizado.',1;
IF @@TRANCOUNT<>0
    THROW 51101,N'Ejecutar sin transacción externa abierta.',1;
IF OBJECT_ID(N'dbo.configuracion_picking_op',N'U') IS NULL
    THROW 51102,N'Falta el esquema de configuración de picking.',1;
IF OBJECT_ID(N'dbo.menu_sistema',N'U') IS NULL OR OBJECT_ID(N'dbo.menu_rol',N'U') IS NULL
    THROW 51103,N'Faltan las tablas de menú BOF.',1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @IdOrigen nvarchar(50),@Padre nvarchar(50),@Nivel int,@SolicitarClave bit;
    DECLARE @IdMenu nvarchar(50),@Siguiente int,@MaxMenuRol int,@NuevosPermisos int;
    DECLARE @MenuCreado bit=0;

    IF (SELECT COUNT(*) FROM dbo.menu_sistema WITH(UPDLOCK,HOLDLOCK)
        WHERE nombre_lgco=N'mnuMantOperadores')<>1
        THROW 51104,N'El menú de Operadores no es único o no existe.',1;

    SELECT @IdOrigen=IdMenu,@Padre=padre,@Nivel=nivel,@SolicitarClave=ISNULL(solicitar_clave_autorizacion,0)
    FROM dbo.menu_sistema WHERE nombre_lgco=N'mnuMantOperadores';
    IF @Nivel IS NULL OR @Nivel<>4 OR @Padre IS NULL OR NOT EXISTS
        (SELECT 1 FROM dbo.menu_sistema WHERE IdMenu=@Padre AND nivel=3 AND nombre_lgco=N'mnuBodega')
        THROW 51105,N'Operadores no está bajo el grupo Bodega esperado por BOF.',1;

    IF (SELECT COUNT(*) FROM dbo.menu_sistema WHERE nombre_lgco=@NombreMenu)>1
        THROW 51106,N'Hay opciones de configuración de picking duplicadas.',1;

    SELECT @IdMenu=IdMenu FROM dbo.menu_sistema WHERE nombre_lgco=@NombreMenu;
    IF @IdMenu IS NULL
    BEGIN
        SELECT @Siguiente=ISNULL(MAX(TRY_CONVERT(int,SUBSTRING(IdMenu,LEN(@Padre)+2,50))),0)+1
        FROM dbo.menu_sistema WITH(UPDLOCK,HOLDLOCK)
        WHERE padre=@Padre AND nivel=4;
        SET @IdMenu=@Padre+N'.'+CONVERT(nvarchar(11),@Siguiente);
        IF EXISTS(SELECT 1 FROM dbo.menu_sistema WHERE IdMenu=@IdMenu)
            THROW 51107,N'El ID de menú calculado ya está ocupado.',1;
        INSERT dbo.menu_sistema(IdMenu,titulo,nombre_lgco,nivel,padre,solicitar_clave_autorizacion)
        VALUES(@IdMenu,N'Configuración de asignación de picking',@NombreMenu,4,@Padre,@SolicitarClave);
        SET @MenuCreado=1;
    END
    ELSE IF EXISTS(SELECT 1 FROM dbo.menu_sistema WHERE IdMenu=@IdMenu AND (ISNULL(nivel,-1)<>4 OR ISNULL(padre,N'')<>@Padre))
        THROW 51108,N'La opción existente pertenece a otra jerarquía; revisar manualmente.',1;

    DECLARE @Permisos TABLE(IdRol int PRIMARY KEY,Leer bit,Modificar bit);
    -- Ante duplicados históricos, heredar únicamente lo permitido por todas las filas.
    INSERT @Permisos(IdRol,Leer,Modificar)
    SELECT IdRol,1,CONVERT(bit,MIN(CONVERT(int,ISNULL(Modificar,0))))
    FROM dbo.menu_rol WITH(UPDLOCK,HOLDLOCK)
    WHERE IdMenu=@IdOrigen
    GROUP BY IdRol
    HAVING MIN(CONVERT(int,ISNULL(activo,0)))=1
       AND MIN(CONVERT(int,ISNULL(visible,0)))=1
       AND MIN(CONVERT(int,ISNULL(Leer,0)))=1;
    IF NOT EXISTS(SELECT 1 FROM @Permisos)
        THROW 51109,N'Operadores no tiene roles de consulta habilitados para heredar.',1;

    SELECT @MaxMenuRol=ISNULL(MAX(IdMenuRol),0) FROM dbo.menu_rol WITH(UPDLOCK,HOLDLOCK);
    ;WITH Faltantes AS
    (
        SELECT p.*,ROW_NUMBER() OVER(ORDER BY p.IdRol) AS Secuencia
        FROM @Permisos p
        WHERE NOT EXISTS(SELECT 1 FROM dbo.menu_rol mr WHERE mr.IdMenu=@IdMenu AND mr.IdRol=p.IdRol)
    )
    INSERT dbo.menu_rol(IdMenuRol,IdMenu,IdRol,user_agr,fec_agr,user_mod,fec_mod,activo,visible,Leer,Modificar,Eliminar)
    SELECT @MaxMenuRol+Secuencia,@IdMenu,IdRol,@Usuario,GETDATE(),@Usuario,GETDATE(),1,1,Leer,Modificar,0
    FROM Faltantes;
    SET @NuevosPermisos=@@ROWCOUNT;

    IF @Aplicar=1 COMMIT TRANSACTION;
    ELSE ROLLBACK TRANSACTION;

    SELECT DB_NAME() AS BaseDatos,@IdMenu AS IdMenu,@NombreMenu AS NombreLogico,@Padre AS Padre,
           @MenuCreado AS MenuCreado,@NuevosPermisos AS PermisosInsertados,
           CASE WHEN @Aplicar=1 THEN N'APLICADO' ELSE N'DRY_RUN_REVERTIDO' END AS Modo;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
