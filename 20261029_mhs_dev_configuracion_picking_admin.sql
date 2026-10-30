/* #EJC20261029_PICKING_CONFIG_ADMIN
   Habilitación explícita del rol Administrador en MHS_DEV.
   No heredó del menú Operadores porque allí tiene Leer=0.
   No modifica Operadores, ancestros ni permisos de otros roles.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit=0;
DECLARE @IdRol int=1;
IF DB_NAME()<>N'TOMWMS_MHS_DEV'
   OR ISNULL(CONVERT(nvarchar(128),SERVERPROPERTY('MachineName')),N'')<>N'MHS-APP-QA'
    THROW 51130,N'Destino no autorizado.',1;
IF @@TRANCOUNT<>0 THROW 51131,N'Ejecutar sin transacción externa.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM dbo.rol WHERE IdRol=@IdRol AND nombre=N'Administrador')
        THROW 51132,N'El rol no corresponde al Administrador esperado.',1;
    DECLARE @IdMenu nvarchar(50),@MaxId int;
    IF (SELECT COUNT(*) FROM dbo.menu_sistema WITH(UPDLOCK,HOLDLOCK)
        WHERE nombre_lgco=N'mnuConfiguracionPickingOp')<>1
        THROW 51133,N'La opción de configuración no existe o es ambigua.',1;
    SELECT @IdMenu=IdMenu FROM dbo.menu_sistema WHERE nombre_lgco=N'mnuConfiguracionPickingOp';
    IF (SELECT COUNT(*) FROM dbo.menu_rol WITH(UPDLOCK,HOLDLOCK) WHERE IdMenu=@IdMenu AND IdRol=@IdRol)>1
        THROW 51134,N'Hay permisos duplicados; revisar antes de habilitar.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.menu_rol WHERE IdMenu=@IdMenu AND IdRol=@IdRol)
    BEGIN
        SELECT @MaxId=ISNULL(MAX(IdMenuRol),0)+1 FROM dbo.menu_rol WITH(UPDLOCK,HOLDLOCK);
        INSERT dbo.menu_rol(IdMenuRol,IdMenu,IdRol,user_agr,fec_agr,user_mod,fec_mod,activo,visible,Leer,Modificar,Eliminar)
        VALUES(@MaxId,@IdMenu,@IdRol,N'EJC_CONFIG_PICKING',GETDATE(),N'EJC_CONFIG_PICKING',GETDATE(),1,1,1,1,0);
    END
    ELSE
        UPDATE dbo.menu_rol SET activo=1,visible=1,Leer=1,Modificar=1,
            user_mod=N'EJC_CONFIG_PICKING',fec_mod=GETDATE()
        WHERE IdMenu=@IdMenu AND IdRol=@IdRol
          AND (ISNULL(activo,0)<>1 OR ISNULL(visible,0)<>1 OR ISNULL(Leer,0)<>1 OR ISNULL(Modificar,0)<>1);
    IF @Aplicar=1 COMMIT TRANSACTION;
    ELSE ROLLBACK TRANSACTION;
    SELECT DB_NAME() AS BaseDatos,@IdMenu AS IdMenu,@IdRol AS IdRol,
        CASE WHEN @Aplicar=1 THEN N'APLICADO' ELSE N'DRY_RUN_REVERTIDO' END AS Modo;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
