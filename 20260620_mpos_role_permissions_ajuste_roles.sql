SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Purpose:
    - Enable the inventory adjustment option and role maintenance option for rol 1.
    - Keep the script reversible with a dry-run mode.

  Scope:
    - Role 1 (AdministradoresDts in QA, per current MCP context)
    - Module 7 = Operaciones
    - Module 4 = Mantenimientos
    - Menu option 80 = Ajuste de mercancia
    - Menu option 93 = Roles y accesos

  Usage:
    - Leave @DryRun = 1 to validate and rollback.
    - Set @DryRun = 0 to commit.
*/

DECLARE @DryRun bit = 1;
DECLARE @RolId int = 1;
DECLARE @ModuloOperaciones int = 7;
DECLARE @ModuloMantenimientos int = 4;
DECLARE @MenuAjuste int = 80;
DECLARE @MenuRoles int = 93;

BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM p_menuopcion
        WHERE id = @MenuAjuste
          AND activo = 1
    )
    BEGIN
        THROW 50000, 'Missing active menu option 80 (Ajuste de mercancia).', 1;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM p_menuopcion
        WHERE id = @MenuRoles
          AND activo = 1
    )
    BEGIN
        THROW 50000, 'Missing active menu option 93 (Roles y accesos).', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM p_modulos_rol
        WHERE rol_id = @RolId
          AND modulo_id = @ModuloOperaciones
    )
    BEGIN
        UPDATE p_modulos_rol
        SET activo = 1
        WHERE rol_id = @RolId
          AND modulo_id = @ModuloOperaciones;
    END
    ELSE
    BEGIN
        INSERT INTO p_modulos_rol (modulo_id, rol_id, activo)
        VALUES (@ModuloOperaciones, @RolId, 1);
    END

    IF EXISTS (
        SELECT 1
        FROM p_modulos_rol
        WHERE rol_id = @RolId
          AND modulo_id = @ModuloMantenimientos
    )
    BEGIN
        UPDATE p_modulos_rol
        SET activo = 1
        WHERE rol_id = @RolId
          AND modulo_id = @ModuloMantenimientos;
    END
    ELSE
    BEGIN
        INSERT INTO p_modulos_rol (modulo_id, rol_id, activo)
        VALUES (@ModuloMantenimientos, @RolId, 1);
    END

    DECLARE @ModuloRolOperaciones int = (
        SELECT TOP 1 id
        FROM p_modulos_rol
        WHERE rol_id = @RolId
          AND modulo_id = @ModuloOperaciones
          AND activo = 1
        ORDER BY id DESC
    );

    DECLARE @ModuloRolMantenimientos int = (
        SELECT TOP 1 id
        FROM p_modulos_rol
        WHERE rol_id = @RolId
          AND modulo_id = @ModuloMantenimientos
          AND activo = 1
        ORDER BY id DESC
    );

    IF @ModuloRolOperaciones IS NULL OR @ModuloRolMantenimientos IS NULL
    BEGIN
        THROW 50001, 'Could not resolve the active module-role ids after sync.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM p_menuopcion_rol
        WHERE modulo_rol_id = @ModuloRolOperaciones
          AND menuopcion_id = @MenuAjuste
    )
    BEGIN
        UPDATE p_menuopcion_rol
        SET activo = 1
        WHERE modulo_rol_id = @ModuloRolOperaciones
          AND menuopcion_id = @MenuAjuste;
    END
    ELSE
    BEGIN
        INSERT INTO p_menuopcion_rol (menuopcion_id, modulo_rol_id, activo)
        VALUES (@MenuAjuste, @ModuloRolOperaciones, 1);
    END

    IF EXISTS (
        SELECT 1
        FROM p_menuopcion_rol
        WHERE modulo_rol_id = @ModuloRolMantenimientos
          AND menuopcion_id = @MenuRoles
    )
    BEGIN
        UPDATE p_menuopcion_rol
        SET activo = 1
        WHERE modulo_rol_id = @ModuloRolMantenimientos
          AND menuopcion_id = @MenuRoles;
    END
    ELSE
    BEGIN
        INSERT INTO p_menuopcion_rol (menuopcion_id, modulo_rol_id, activo)
        VALUES (@MenuRoles, @ModuloRolMantenimientos, 1);
    END

    SELECT
        mr.id AS modulo_rol_id,
        mr.rol_id,
        mr.modulo_id,
        mr.activo AS modulo_activo,
        mo.id AS menuopcion_id,
        mo.nombre AS menu_nombre,
        mo.enlace AS menu_enlace,
        mor.activo AS permiso_activo
    FROM p_modulos_rol mr
    LEFT JOIN p_menuopcion_rol mor
        ON mor.modulo_rol_id = mr.id
       AND mor.menuopcion_id IN (@MenuAjuste, @MenuRoles)
    LEFT JOIN p_menuopcion mo
        ON mo.id = mor.menuopcion_id
    WHERE mr.rol_id = @RolId
      AND mr.modulo_id IN (@ModuloMantenimientos, @ModuloOperaciones)
    ORDER BY mr.modulo_id, mo.id;

    IF @DryRun = 1
    BEGIN
        ROLLBACK TRAN;
        PRINT 'Dry-run completed. No changes were committed.';
    END
    ELSE
    BEGIN
        COMMIT TRAN;
        PRINT 'Changes committed.';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
