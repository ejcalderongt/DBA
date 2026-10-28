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

    IF OBJECT_ID('tempdb..#BaseUbicaciones') IS NOT NULL DROP TABLE #BaseUbicaciones;
    IF OBJECT_ID('tempdb..#CeldasCandidatas') IS NOT NULL DROP TABLE #CeldasCandidatas;
    IF OBJECT_ID('tempdb..#ConteoProductoPorColumna') IS NOT NULL DROP TABLE #ConteoProductoPorColumna;

    SELECT
        v.IdUbicacion,
        v.IdBodega,
        v.IdTramo,
        v.nivel,
        v.indice_x AS Indice_X,
        v.IdStock,
        v.orientacion_pos,
        v.bloqueada,
        v.acepta_pallet,
        v.ubicacion_merma,
        v.[dañado]
    INTO #BaseUbicaciones
    FROM VW_Ubicaciones_Tramo_Disponibles v
    WHERE v.IdBodega = @IdBodega
      AND v.IdTramo = @IdTramo;

    SELECT
        @IdBodega AS IdBodega,
        @IdTramo AS IdTramo,
        COUNT(1) AS Total_Ubicaciones,
        SUM(CASE WHEN IdStock = 0 THEN 1 ELSE 0 END) AS Ubicaciones_Vacias,
        COUNT(DISTINCT CASE WHEN IdStock <> 0 THEN nivel END) AS Niveles_Ocupados,
        COUNT(DISTINCT CASE WHEN IdStock <> 0 THEN Indice_X END) AS Columnas_Ocupadas
    FROM #BaseUbicaciones;

    SELECT
        b.IdUbicacion,
        b.IdBodega,
        b.IdTramo,
        b.nivel,
        b.Indice_X,
        b.IdStock,
        CASE WHEN b.IdStock = 0 THEN 1 ELSE 0 END AS EsVacia,
        CASE WHEN b.IdStock <> 0 THEN 1 ELSE 0 END AS EsOcupada
    INTO #CeldasCandidatas
    FROM #BaseUbicaciones b;

    SELECT
        s.Ubicacion_Indice_X AS Columna,
        COUNT(1) AS CantidadProducto
    INTO #ConteoProductoPorColumna
    FROM VW_STOCK_RES s
    WHERE s.IdBodega = @IdBodega
      AND s.IdTramo = @IdTramo
      AND s.IdProductoBodega = @IdProductoBodega
      AND s.IdStock <> 0
    GROUP BY s.Ubicacion_Indice_X;

    SELECT
        c.IdUbicacion,
        c.IdBodega,
        c.IdTramo,
        c.nivel,
        c.Indice_X,
        c.IdStock,
        c.EsVacia,
        c.EsOcupada,
        ISNULL(cp.CantidadProducto, 0) AS CantidadProducto,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM VW_STOCK_RES s
            WHERE s.IdBodega = @IdBodega
              AND s.IdTramo = @IdTramo
              AND s.IdProductoBodega = @IdProductoBodega
              AND (@Lote = N'' OR s.Lote LIKE N'%' + @Lote + N'%')
              AND s.Lote = s.Lote
        ) THEN 1 ELSE 0 END AS MatchLote,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM VW_STOCK_RES s
            WHERE s.IdBodega = @IdBodega
              AND s.IdTramo = @IdTramo
              AND s.IdProductoBodega = @IdProductoBodega
              AND @FechaVence IS NOT NULL
              AND s.Fecha_Vence BETWEEN @FechaVenceMin AND @FechaVenceMax
              AND s.Fecha_Vence = s.Fecha_Vence
        ) THEN 1 ELSE 0 END AS MatchVence,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM VW_STOCK_RES s
            WHERE s.IdBodega = @IdBodega
              AND s.IdTramo = @IdTramo
              AND s.IdProductoBodega = @IdProductoBodega
              AND (@IdProductoEstado = 0 OR s.IdProductoEstado = @IdProductoEstado)
              AND s.IdProductoEstado = s.IdProductoEstado
        ) THEN 1 ELSE 0 END AS MatchEstado
    FROM #CeldasCandidatas c
    LEFT JOIN #ConteoProductoPorColumna cp
        ON cp.Columna = c.Indice_X
    WHERE c.EsVacia = 1
    ORDER BY c.Indice_X, c.nivel, c.IdUbicacion;
END
