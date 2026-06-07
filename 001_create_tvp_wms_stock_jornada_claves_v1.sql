IF TYPE_ID(N'dbo.tvp_wms_stock_jornada_claves_v1') IS NULL
BEGIN
    CREATE TYPE dbo.tvp_wms_stock_jornada_claves_v1 AS TABLE
    (
        LicPlate NVARCHAR(120) NULL,
        IdPropietarioBodega INT NULL,
        IdProductoBodega INT NULL,
        IdStock INT NULL,
        StockJornadaHash NVARCHAR(128) NULL,
        IdTicketTMS INT NULL,
        IdRecepcionEnc INT NULL,
        IdRecepcionDet INT NULL
    );
END;
