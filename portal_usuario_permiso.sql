-- Permisos explícitos por usuario delegado. La ausencia de fila deniega.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.portal_usuario_permiso', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.portal_usuario_permiso (
        IdPortalUsuario int NOT NULL,
        CodigoPermiso nvarchar(100) NOT NULL,
        FechaAsignacion datetime2(0) NOT NULL CONSTRAINT DF_portal_usuario_permiso_fecha DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_portal_usuario_permiso PRIMARY KEY (IdPortalUsuario, CodigoPermiso),
        CONSTRAINT FK_portal_usuario_permiso_usuario FOREIGN KEY (IdPortalUsuario)
            REFERENCES dbo.portal_usuario (IdPortalUsuario)
    );
END;
