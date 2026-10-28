-- #EJC20261012_DB_MIGRATION
-- Permite que una base restaurada alcance el contrato esperado por clsLnBodega.
-- Es idempotente: puede ejecutarse nuevamente sin duplicar columna ni constraints.

IF OBJECT_ID(N'dbo.bodega', N'U') IS NULL
BEGIN
    THROW 51000, 'No existe dbo.bodega; la base no corresponde a una estructura WMS compatible.', 1;
END;
GO

IF COL_LENGTH(N'dbo.bodega', N'tiempo_inactividad_hh_minutos') IS NULL
BEGIN
    ALTER TABLE dbo.bodega
    ADD tiempo_inactividad_hh_minutos INT NOT NULL
        CONSTRAINT DF_bodega_tiempo_inactividad_hh_minutos
        DEFAULT (10) WITH VALUES;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_bodega_tiempo_inactividad_hh_minutos'
      AND parent_object_id = OBJECT_ID(N'dbo.bodega')
)
BEGIN
    ALTER TABLE dbo.bodega WITH CHECK
    ADD CONSTRAINT CK_bodega_tiempo_inactividad_hh_minutos
        CHECK (tiempo_inactividad_hh_minutos BETWEEN 1 AND 1440);

    ALTER TABLE dbo.bodega
    CHECK CONSTRAINT CK_bodega_tiempo_inactividad_hh_minutos;
END;
GO

IF COL_LENGTH(N'dbo.bodega', N'tiempo_inactividad_hh_minutos') IS NULL
BEGIN
    THROW 51001, 'No fue posible crear dbo.bodega.tiempo_inactividad_hh_minutos.', 1;
END;
GO
