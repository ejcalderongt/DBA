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
