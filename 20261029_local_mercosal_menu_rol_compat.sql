/*
    #EJC20261029_PICKING_MENU_COMPAT
    Exclusivamente copia LOCAL de MERCOSAL en prograx.
    Esta copia tiene menu_rol antiguo (solo activo/visible). El BOF actual espera
    Leer/Modificar/Eliminar. En el código legado Get_MenuRol_Opciones devolvía
    los valores True de clsBeOpcionesMenuRol cuando faltaban estas columnas.
    DEFAULT(1) conserva ese comportamiento para las filas históricas; no cambia
    activo/visible ni añade asignaciones a roles. La opción nueva de configuración
    se inserta después con Eliminar=0 y permisos heredados explícitos.
    No ejecutar en MERCOSAL remoto ni en bases con políticas finas ya configuradas.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0;
DECLARE @BaseEsperada sysname=N'IMS4MB_MERCOSAL_PRD';
IF DB_NAME()<>@BaseEsperada OR ISNULL(CONVERT(nvarchar(128),SERVERPROPERTY('MachineName')),N'')<>N'prograx'
    THROW 51120,N'Destino no autorizado: solo copia MERCOSAL local.',1;
IF @@TRANCOUNT<>0 THROW 51121,N'Ejecutar sin transacción externa.',1;
IF OBJECT_ID(N'dbo.menu_rol',N'U') IS NULL THROW 51122,N'Falta dbo.menu_rol.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    IF COL_LENGTH(N'dbo.menu_rol',N'Leer') IS NULL
        ALTER TABLE dbo.menu_rol ADD Leer bit NOT NULL CONSTRAINT DF_menu_rol_leer_compat DEFAULT(1) WITH VALUES;
    IF COL_LENGTH(N'dbo.menu_rol',N'Modificar') IS NULL
        ALTER TABLE dbo.menu_rol ADD Modificar bit NOT NULL CONSTRAINT DF_menu_rol_modificar_compat DEFAULT(1) WITH VALUES;
    IF COL_LENGTH(N'dbo.menu_rol',N'Eliminar') IS NULL
        ALTER TABLE dbo.menu_rol ADD Eliminar bit NOT NULL CONSTRAINT DF_menu_rol_eliminar_compat DEFAULT(1) WITH VALUES;
    IF @Aplicar=1 COMMIT TRANSACTION;
    ELSE ROLLBACK TRANSACTION;
    SELECT DB_NAME() AS BaseDatos,CASE WHEN @Aplicar=1 THEN N'APLICADO' ELSE N'DRY_RUN_REVERTIDO' END AS Modo;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
