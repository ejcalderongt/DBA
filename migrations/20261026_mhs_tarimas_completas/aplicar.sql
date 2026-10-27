-- #EJC20261026_MHS_TARIMA_COMPLETA
SET XACT_ABORT ON;
IF OBJECT_ID('dbo.trans_licencia_empaque','U') IS NULL
    THROW 51000, 'Falta dbo.trans_licencia_empaque.', 1;
IF COL_LENGTH('dbo.trans_licencia_empaque','EsRecicladaRecepcion') IS NULL
    ALTER TABLE dbo.trans_licencia_empaque ADD EsRecicladaRecepcion bit NOT NULL
        CONSTRAINT DF_trans_licencia_empaque_EsRecicladaRecepcion DEFAULT (0) WITH VALUES;
