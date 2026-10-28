-- #EJC20261026_MHS_TARIMA_COMPLETA: primero revertir binarios BOF/WS.
SET XACT_ABORT ON;
IF COL_LENGTH('dbo.trans_licencia_empaque','EsRecicladaRecepcion') IS NOT NULL
BEGIN
    EXEC(N'IF EXISTS(SELECT 1 FROM dbo.trans_licencia_empaque WHERE EsRecicladaRecepcion=1)
        THROW 51000, ''Existen licencias recicladas: no se puede perder su trazabilidad.'', 1;');
    ALTER TABLE dbo.trans_licencia_empaque DROP CONSTRAINT DF_trans_licencia_empaque_EsRecicladaRecepcion;
    ALTER TABLE dbo.trans_licencia_empaque DROP COLUMN EsRecicladaRecepcion;
END;
