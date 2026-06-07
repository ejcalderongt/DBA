IF OBJECT_ID(N'dbo.usp_wms_stock_jornada_preload_ctx_tvp_v1', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE dbo.usp_wms_stock_jornada_preload_ctx_tvp_v1 AS BEGIN SET NOCOUNT ON; END');
END;
GO

ALTER PROCEDURE dbo.usp_wms_stock_jornada_preload_ctx_tvp_v1
    @FechaDesde DATE,
    @FechaHasta DATE,
    @Claves dbo.tvp_wms_stock_jornada_claves_v1 READONLY
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaDesde IS NULL SET @FechaDesde = CAST(GETDATE() AS DATE);
    IF @FechaHasta IS NULL SET @FechaHasta = CAST(GETDATE() AS DATE);
    IF @FechaDesde > @FechaHasta
    BEGIN
        DECLARE @Tmp DATE = @FechaDesde;
        SET @FechaDesde = @FechaHasta;
        SET @FechaHasta = @Tmp;
    END;

    ;WITH C AS
    (
        SELECT DISTINCT
            UPPER(LTRIM(RTRIM(ISNULL(LicPlate, '')))) AS LicPlate,
            ISNULL(IdPropietarioBodega, 0) AS IdPropietarioBodega,
            ISNULL(IdProductoBodega, 0) AS IdProductoBodega,
            ISNULL(IdStock, 0) AS IdStock,
            UPPER(LTRIM(RTRIM(ISNULL(StockJornadaHash, '')))) AS StockJornadaHash,
            ISNULL(IdTicketTMS, 0) AS IdTicketTMS,
            ISNULL(IdRecepcionEnc, 0) AS IdRecepcionEnc,
            ISNULL(IdRecepcionDet, 0) AS IdRecepcionDet
        FROM @Claves
    )
    SELECT DISTINCT
        t.IdTicket AS IdTicketTMS
    FROM tms_ticket t
    INNER JOIN C
        ON C.IdTicketTMS = t.IdTicket
       AND C.IdTicketTMS > 0
    WHERE ISNULL(t.procesado_stock_jornada, 0) = 1;

    ;WITH C AS
    (
        SELECT DISTINCT
            UPPER(LTRIM(RTRIM(ISNULL(LicPlate, '')))) AS LicPlate,
            ISNULL(IdRecepcionEnc, 0) AS IdRecepcionEnc,
            ISNULL(IdRecepcionDet, 0) AS IdRecepcionDet
        FROM @Claves
    )
    SELECT DISTINCT
        tr.Lic_plate AS LicPlate,
        tr.IdRecepcionEnc,
        tr.IdRecepcionDet
    FROM trans_re_det tr
    INNER JOIN C
        ON UPPER(LTRIM(RTRIM(ISNULL(tr.Lic_plate, '')))) = C.LicPlate
       AND ISNULL(tr.IdRecepcionEnc, 0) = C.IdRecepcionEnc
       AND ISNULL(tr.IdRecepcionDet, 0) = C.IdRecepcionDet
    WHERE ISNULL(tr.IdJornadaSistema, 0) > 0;

    ;WITH C AS
    (
        SELECT DISTINCT
            UPPER(LTRIM(RTRIM(ISNULL(LicPlate, '')))) AS LicPlate,
            ISNULL(IdPropietarioBodega, 0) AS IdPropietarioBodega,
            ISNULL(IdProductoBodega, 0) AS IdProductoBodega,
            ISNULL(IdStock, 0) AS IdStock
        FROM @Claves
    )
    SELECT DISTINCT
        sj.Lic_plate AS LicPlate,
        CAST(sj.Fecha AS DATE) AS Fecha,
        sj.IdPropietarioBodega,
        sj.IdProductoBodega,
        sj.IdStock
    FROM stock_jornada sj
    INNER JOIN C
        ON UPPER(LTRIM(RTRIM(ISNULL(sj.Lic_plate, '')))) = C.LicPlate
       AND ISNULL(sj.IdPropietarioBodega, 0) = C.IdPropietarioBodega
       AND ISNULL(sj.IdProductoBodega, 0) = C.IdProductoBodega
       AND ISNULL(sj.IdStock, 0) = C.IdStock
    WHERE CAST(sj.Fecha AS DATE) BETWEEN @FechaDesde AND @FechaHasta;

    ;WITH C AS
    (
        SELECT DISTINCT
            UPPER(LTRIM(RTRIM(ISNULL(StockJornadaHash, '')))) AS StockJornadaHash
        FROM @Claves
        WHERE ISNULL(StockJornadaHash, '') <> ''
    )
    SELECT DISTINCT
        sj.Stock_Jornada_Hash,
        CAST(sj.Fecha AS DATE) AS Fecha
    FROM stock_jornada sj
    INNER JOIN C
        ON UPPER(LTRIM(RTRIM(ISNULL(sj.Stock_Jornada_Hash, '')))) = C.StockJornadaHash
    WHERE ISNULL(sj.es_retroactivo, 0) = 1
      AND ISNULL(sj.Stock_Jornada_Hash, '') <> ''
      AND CAST(sj.Fecha AS DATE) BETWEEN @FechaDesde AND @FechaHasta;

    SELECT DISTINCT
        CAST(js.Fecha AS DATE) AS Fecha
    FROM jornada_sistema js
    WHERE CAST(js.Fecha AS DATE) BETWEEN @FechaDesde AND @FechaHasta;
END;
GO
