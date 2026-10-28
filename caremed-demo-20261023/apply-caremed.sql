SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_CAREMED_PRD' OR CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) <> N'prograx\SQLEXPRESS' THROW 50000,'Entorno incorrecto',1;
BEGIN TRAN;
-- Usuarios humanos delegados del portal. El propietario legacy sigue siendo la cuenta inicial.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.portal_usuario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.portal_usuario (
        IdPortalUsuario int IDENTITY(1,1) NOT NULL CONSTRAINT PK_portal_usuario PRIMARY KEY,
        IdPropietario int NOT NULL,
        CodigoAcceso nvarchar(100) NOT NULL,
        Nombre nvarchar(150) NOT NULL,
        Email nvarchar(254) NULL,
        ClaveHash nvarchar(512) NOT NULL,
        EsAdministrador bit NOT NULL CONSTRAINT DF_portal_usuario_admin DEFAULT (0),
        Activo bit NOT NULL CONSTRAINT DF_portal_usuario_activo DEFAULT (1),
        FechaCreacion datetime2(0) NOT NULL CONSTRAINT DF_portal_usuario_fecha DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_portal_usuario_propietarios FOREIGN KEY (IdPropietario)
            REFERENCES dbo.propietarios (IdPropietario),
        CONSTRAINT UQ_portal_usuario_codigo UNIQUE (CodigoAcceso)
    );

    CREATE INDEX IX_portal_usuario_propietario
        ON dbo.portal_usuario (IdPropietario, Activo);
END;

-- Habilitaciones definidas por la empresa. El propietario no puede modificarlas.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.portal_propietario_modulo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.portal_propietario_modulo (
        IdPropietario int NOT NULL,
        CodigoModulo nvarchar(50) NOT NULL,
        Habilitado bit NOT NULL CONSTRAINT DF_portal_propietario_modulo_habilitado DEFAULT (1),
        FechaModificacion datetime2(0) NOT NULL CONSTRAINT DF_portal_propietario_modulo_fecha DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_portal_propietario_modulo PRIMARY KEY (IdPropietario, CodigoModulo),
        CONSTRAINT FK_portal_propietario_modulo_propietarios FOREIGN KEY (IdPropietario)
            REFERENCES dbo.propietarios (IdPropietario)
    );
END;

-- Estado inicial solicitado: todos los módulos disponibles para propietarios activos.
-- La ausencia de una fila se interpreta como denegación.
INSERT INTO dbo.portal_propietario_modulo (IdPropietario, CodigoModulo)
SELECT p.IdPropietario, m.CodigoModulo
FROM dbo.propietarios AS p
CROSS JOIN (VALUES
    (N'inventario'), (N'ingresos'), (N'salidas'), (N'indicadores'),
    (N'analisis'), (N'kairos'), (N'automatizaciones')
) AS m(CodigoModulo)
WHERE p.activo = 1
  AND NOT EXISTS (
      SELECT 1 FROM dbo.portal_propietario_modulo AS pm
      WHERE pm.IdPropietario = p.IdPropietario AND pm.CodigoModulo = m.CodigoModulo
  );

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

COMMIT;
