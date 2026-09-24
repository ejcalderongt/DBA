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
