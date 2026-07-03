CREATE OR ALTER PROCEDURE dbo.ml_get_ubicacion_sugerida_preload_tramo
    @IdBodega INT,
    @IdTramo INT,
    @IdProductoBodega INT,
    @IdProducto INT,
    @Lote NVARCHAR(100) = N'',
    @FechaVence DATE = NULL,
    @IdProductoEstado INT = 0,
    @IdUmBas INT = 0,
    @IdPresentacion INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaVenceMin DATE = NULL;
    DECLARE @FechaVenceMax DATE = NULL;

    IF @FechaVence IS NOT NULL
    BEGIN
        SET @FechaVenceMin = DATEADD(DAY, -30, @FechaVence);
        SET @FechaVenceMax = DATEADD(DAY, 30, @FechaVence);
    END

    ;WITH BaseUbicaciones AS
    (
        SELECT
            v.IdUbicacion,
            v.IdBodega,
            v.IdTramo,
            v.Nivel,
            v.Indice_X,
            v.IdStock,
            v.orientacion_pos,
            v.bloqueada,
            v.acepta_pallet,
            v.ubicacion_merma,
            v.[dañado]
        FROM VW_Ubicaciones_Tramo_Disponibles v
        WHERE v.IdBodega = @IdBodega
          AND v.IdTramo = @IdTramo
    ),
    ResumenTramo AS
    (
        SELECT
            @IdBodega AS IdBodega,
            @IdTramo AS IdTramo,
            COUNT(1) AS Total_Ubicaciones,
            SUM(CASE WHEN IdStock = 0 THEN 1 ELSE 0 END) AS Ubicaciones_Vacias,
            COUNT(DISTINCT CASE WHEN IdStock <> 0 THEN Nivel END) AS Niveles_Ocupados,
            COUNT(DISTINCT CASE WHEN IdStock <> 0 THEN Indice_X END) AS Columnas_Ocupadas
        FROM VW_OcupacionBodegaTramo
        WHERE IdBodega = @IdBodega
          AND IdTramo = @IdTramo
    ),
    CeldasCandidatas AS
    (
        SELECT
            b.IdUbicacion,
            b.IdBodega,
            b.IdTramo,
            b.Nivel,
            b.Indice_X,
            b.IdStock,
            CASE WHEN b.IdStock = 0 THEN 1 ELSE 0 END AS EsVacia,
            CASE WHEN b.IdStock <> 0 THEN 1 ELSE 0 END AS EsOcupada
        FROM BaseUbicaciones b
    ),
    ConteoProductoPorColumna AS
    (
        SELECT
            s.Indice_X AS Columna,
            COUNT(1) AS CantidadProducto
        FROM VW_STOCK_RES s
        WHERE s.IdBodega = @IdBodega
          AND s.IdTramo = @IdTramo
          AND s.IdProductoBodega = @IdProductoBodega
          AND s.IdStock <> 0
        GROUP BY s.Indice_X
    ),
    AtributosLote AS
    (
        SELECT DISTINCT
            s.IdProductoEstado,
            s.IdUnidadMedida,
            s.IdPresentacion,
            s.Lote,
            s.Fecha_Vence
        FROM VW_STOCK_RES s
        WHERE s.IdBodega = @IdBodega
          AND s.IdTramo = @IdTramo
          AND s.IdProductoBodega = @IdProductoBodega
          AND (@Lote = N'' OR s.Lote LIKE N'%' + @Lote + N'%')
    ),
    AtributosVence AS
    (
        SELECT DISTINCT
            s.IdProductoEstado,
            s.IdUnidadMedida,
            s.IdPresentacion,
            s.Lote,
            s.Fecha_Vence
        FROM VW_STOCK_RES s
        WHERE s.IdBodega = @IdBodega
          AND s.IdTramo = @IdTramo
          AND s.IdProductoBodega = @IdProductoBodega
          AND @FechaVence IS NOT NULL
          AND s.Fecha_Vence BETWEEN @FechaVenceMin AND @FechaVenceMax
    ),
    AtributosEstado AS
    (
        SELECT DISTINCT
            s.IdProductoEstado,
            s.IdUnidadMedida,
            s.IdPresentacion,
            s.Lote,
            s.Fecha_Vence
        FROM VW_STOCK_RES s
        WHERE s.IdBodega = @IdBodega
          AND s.IdTramo = @IdTramo
          AND s.IdProductoBodega = @IdProductoBodega
          AND (@IdProductoEstado = 0 OR s.IdProductoEstado = @IdProductoEstado)
    )
    SELECT
        r.IdBodega,
        r.IdTramo,
        r.Total_Ubicaciones,
        r.Ubicaciones_Vacias,
        r.Niveles_Ocupados,
        r.Columnas_Ocupadas
    FROM ResumenTramo r;

    SELECT
        c.IdUbicacion,
        c.IdBodega,
        c.IdTramo,
        c.Nivel,
        c.Indice_X,
        c.IdStock,
        c.EsVacia,
        c.EsOcupada,
        ISNULL(cp.CantidadProducto, 0) AS CantidadProducto,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM AtributosLote a
            WHERE (@Lote = N'' OR a.Lote LIKE N'%' + @Lote + N'%')
        ) THEN 1 ELSE 0 END AS MatchLote,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM AtributosVence a
        ) THEN 1 ELSE 0 END AS MatchVence,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM AtributosEstado a
            WHERE (@IdProductoEstado = 0 OR a.IdProductoEstado = @IdProductoEstado)
        ) THEN 1 ELSE 0 END AS MatchEstado
    FROM CeldasCandidatas c
    LEFT JOIN ConteoProductoPorColumna cp
        ON cp.Columna = c.Indice_X
    WHERE c.EsVacia = 1
    ORDER BY c.Indice_X, c.Nivel, c.IdUbicacion;
END
