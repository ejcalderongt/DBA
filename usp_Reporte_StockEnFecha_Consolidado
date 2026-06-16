/*
EJC20260602_STOCK_FECHA
Optimización para reporte "Stock en una fecha"

Carol, aquí dejamos los bloques SQL para acelerar el reporte sin cambiar su lógica funcional:
1) Índices de soporte para filtros por bodega/propietario/producto/fecha.
2) SP de snapshot de existencias para evitar N+1 en capa VB.
3) SP de movimientos con filtro sargable por fecha.
*/

SET NOCOUNT ON;
GO

/* =========================================================
   1) Índices de soporte
   ========================================================= */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.trans_movimientos')
      AND name = N'IX_trans_movimientos_stock_en_fecha'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trans_movimientos_stock_en_fecha
        ON dbo.trans_movimientos (
            IdBodegaOrigen,
            IdPropietarioBodega,
            IdProductoBodega,
            fecha,
            IdTipoTarea
        )
        INCLUDE (
            cantidad,
            lote,
            fecha_vence,
            IdEstadoOrigen,
            IdEstadoDestino,
            IdPresentacion,
            IdUnidadMedida,
            IdTransaccion
        );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.stock')
      AND name = N'IX_stock_snapshot_stock_en_fecha'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_stock_snapshot_stock_en_fecha
        ON dbo.stock (
            IdBodega,
            IdPropietarioBodega,
            IdProductoBodega,
            IdProductoEstado,
            IdUnidadMedida,
            IdPresentacion,
            lote,
            fecha_vence,
            activo
        )
        INCLUDE (
            cantidad,
            IdUbicacion
        );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.bodega_ubicacion')
      AND name = N'IX_bodega_ubicacion_despacho_lookup'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_bodega_ubicacion_despacho_lookup
        ON dbo.bodega_ubicacion (
            IdBodega,
            ubicacion_despacho,
            IdUbicacion
        );
END
GO

/* =========================================================
   2) Snapshot de existencias (para consumo del reporte)
   ========================================================= */

IF OBJECT_ID(N'dbo.usp_Reporte_StockEnFecha_Snapshot', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Reporte_StockEnFecha_Snapshot;
GO

CREATE PROCEDURE dbo.usp_Reporte_StockEnFecha_Snapshot
    @IdBodega INT,
    @IdPropietarioBodega INT,
    @IdProductoBodega INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdProductoBodega,
        IdProductoEstado,
        ISNULL(IdPresentacion, 0) AS IdPresentacion,
        IdUnidadMedida,
        ISNULL(lote, '') AS lote,
        CAST(fecha_vence AS DATE) AS fecha_vence,
        SUM(Disponible_UMBas) AS Disponible_UMBas
    FROM dbo.VW_Stock_Res
    WHERE IdBodega = @IdBodega
      AND IdPropietarioBodega = @IdPropietarioBodega
      AND (@IdProductoBodega IS NULL OR IdProductoBodega = @IdProductoBodega)
    GROUP BY
        IdProductoBodega,
        IdProductoEstado,
        ISNULL(IdPresentacion, 0),
        IdUnidadMedida,
        ISNULL(lote, ''),
        CAST(fecha_vence AS DATE);
END
GO

/* =========================================================
   3) Movimientos sargables para stock en fecha
   ========================================================= */

IF OBJECT_ID(N'dbo.usp_Reporte_StockEnFecha_Movimientos', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Reporte_StockEnFecha_Movimientos;
GO

CREATE PROCEDURE dbo.usp_Reporte_StockEnFecha_Movimientos
    @FechaDel DATE,
    @FechaAl DATE,
    @IdBodega INT,
    @IdPropietarioBodega INT,
    @IdProductoBodega INT = NULL,
    @Lote NVARCHAR(100) = NULL,
    @SoloProductosConStock BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- EJC20260602_STOCK_FECHA_FASE3_TIMEOUT: materializa productos con stock para evitar EXISTS por fila sobre la vista.
    ;WITH ProductosConStock AS (
        SELECT DISTINCT s.IdProductoBodega
        FROM dbo.VW_Stock_Res s
        WHERE s.IdBodega = @IdBodega
          AND s.IdPropietarioBodega = @IdPropietarioBodega
          AND ISNULL(s.Disponible_UMBas, 0) > 0
    )

    SELECT
        m.Codigo,
        m.Producto,
        SUM(m.cantidad) AS Cantidad,
        m.EstadoOrigen,
        m.EstadoDestino,
        m.TipoTarea,
        MAX(ISNULL(pp.nombre, '')) AS Presentacion,
        m.lote,
        m.Fecha_Vence,
        m.IdTipoTarea,
        m.IdPresentacion,
        m.IdUnidadMedida,
        m.IdEstadoOrigen,
        m.IdProductoBodega,
        m.Fecha,
        m.Umbas,
        m.Operador
    FROM dbo.VW_Movimientos_N m
    LEFT JOIN dbo.producto_presentacion pp ON pp.IdPresentacion = m.IdPresentacion
    WHERE m.IdBodega = @IdBodega
      AND m.IdPropietarioBodega = @IdPropietarioBodega
      AND (@IdProductoBodega IS NULL OR m.IdProductoBodega = @IdProductoBodega)
      AND (@Lote IS NULL OR m.lote = @Lote)
      -- EJC20260602_STOCK_FECHA_FASE3: filtro de solo con stock usando set pre-materializado.
      AND (@SoloProductosConStock = 0 OR m.IdProductoBodega IN (SELECT pcs.IdProductoBodega FROM ProductosConStock pcs))
      AND m.Fecha >= @FechaDel
      AND m.Fecha < DATEADD(DAY, 1, @FechaAl)
      AND m.TipoTarea NOT IN ('PIK', 'VERI', 'REEMP_BE_PICK', 'CEST')
    GROUP BY
        m.codigo,
        m.producto,
        m.EstadoOrigen,
        m.EstadoDestino,
        m.IdProductoBodega,
        m.TipoTarea,
        m.lote,
        m.fecha_vence,
        m.IdTipoTarea,
        m.Fecha,
        m.IdPresentacion,
        m.IdUnidadMedida,
        m.IdEstadoOrigen,
        m.Umbas,
        m.Operador
    ORDER BY
        Fecha,
        Codigo,
        fecha_vence,
        Lote;
END
GO

/* =========================================================
   4) Dataset final consolidado para UI (una sola llamada)
   ========================================================= */

IF OBJECT_ID(N'dbo.usp_Reporte_StockEnFecha_Consolidado', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Reporte_StockEnFecha_Consolidado;
GO

CREATE PROCEDURE dbo.usp_Reporte_StockEnFecha_Consolidado
    @FechaDel DATE,
    @FechaAl DATE,
    @IdBodega INT,
    @IdPropietarioBodega INT,
    @IdProductoBodega INT = NULL,
    @Lote NVARCHAR(100) = NULL,
    @IncluirUbicacionesDespacho BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH MovBase AS (
        SELECT
            m.IdProductoBodega,
            m.codigo AS Codigo,
            m.Producto,
            m.EstadoOrigen,
            m.IdEstadoOrigen,
            ISNULL(m.IdPresentacion, 0) AS IdPresentacion,
            m.IdUnidadMedida,
            ISNULL(m.lote, '') AS Lote,
            CAST(m.Fecha_Vence AS DATE) AS Fecha_Vence,
            SUM(CASE WHEN m.TipoTarea = 'INVE' THEN m.cantidad ELSE 0 END) AS Inventario_Inicial_UMBas,
            SUM(CASE WHEN m.TipoTarea = 'RECE' THEN m.cantidad ELSE 0 END) AS Ingresos_UMBas,
            -- EJC20260602_STOCK_FECHA_FASE2: incluir reclasificaciones generadas por regularización (lote/vencimiento/estado).
            SUM(CASE WHEN m.TipoTarea IN ('AJCANTP','AJCANTPI','AJLOTE','AJLOTEPI','AJVENC','AJVENCEPI','CESTI','CEST') THEN m.cantidad ELSE 0 END) AS AjustePositivo_UMBas,
            SUM(CASE WHEN m.TipoTarea IN ('AJCANTN','AJCANTNI','AJLOTENI','AJVENCENI') THEN m.cantidad ELSE 0 END) AS AjusteNegativo_UMBas,
            SUM(CASE WHEN m.TipoTarea IN ('DESP','TRAS') THEN m.cantidad ELSE 0 END) AS Salidas_UMBas
        FROM dbo.VW_Movimientos_N m
        WHERE m.IdBodega = @IdBodega
          AND m.IdPropietarioBodega = @IdPropietarioBodega
          AND (@IdProductoBodega IS NULL OR m.IdProductoBodega = @IdProductoBodega)
          AND (@Lote IS NULL OR ISNULL(m.lote,'') COLLATE DATABASE_DEFAULT = @Lote COLLATE DATABASE_DEFAULT)
          AND m.Fecha >= @FechaDel
          AND m.Fecha < DATEADD(DAY, 1, @FechaAl)
          -- EJC20260602_STOCK_FECHA_FASE2: ampliar ventana de tipos para no perder "inventario/ajuste" en medio del rango.
          AND m.TipoTarea IN ('INVE','RECE','AJCANTP','AJCANTPI','AJCANTN','AJCANTNI','AJLOTE','AJLOTEPI','AJLOTENI','AJVENC','AJVENCEPI','AJVENCENI','CESTI','CEST','DESP','TRAS')
        GROUP BY
            m.IdProductoBodega,
            m.codigo,
            m.Producto,
            m.EstadoOrigen,
            m.IdEstadoOrigen,
            ISNULL(m.IdPresentacion, 0),
            m.IdUnidadMedida,
            ISNULL(m.lote, ''),
            CAST(m.Fecha_Vence AS DATE)
    ),
    SnapConEstado AS (
        SELECT
            s.IdProductoBodega,
            s.IdProductoEstado AS IdEstadoOrigen,
            ISNULL(s.IdPresentacion, 0) AS IdPresentacion,
            s.IdUnidadMedida,
            ISNULL(s.lote, '') AS Lote,
            CAST(s.fecha_vence AS DATE) AS Fecha_Vence,
            SUM(s.Disponible_UMBas) AS Existencia_Actual_UMBas
        FROM dbo.VW_Stock_Res s
        WHERE s.IdBodega = @IdBodega
          AND s.IdPropietarioBodega = @IdPropietarioBodega
          AND (@IdProductoBodega IS NULL OR s.IdProductoBodega = @IdProductoBodega)
          AND (@Lote IS NULL OR ISNULL(s.lote,'') COLLATE DATABASE_DEFAULT = @Lote COLLATE DATABASE_DEFAULT)
          AND (
                @IncluirUbicacionesDespacho = 1
                OR s.IdUbicacion NOT IN (
                    SELECT bu.IdUbicacion
                    FROM dbo.bodega_ubicacion bu
                    WHERE bu.IdBodega = @IdBodega
                      AND bu.ubicacion_despacho = 1
                )
              )
        GROUP BY
            s.IdProductoBodega,
            s.IdProductoEstado,
            ISNULL(s.IdPresentacion, 0),
            s.IdUnidadMedida,
            ISNULL(s.lote, ''),
            CAST(s.fecha_vence AS DATE)
    ),
    SnapSinEstado AS (
        SELECT
            s.IdProductoBodega,
            ISNULL(s.IdPresentacion, 0) AS IdPresentacion,
            s.IdUnidadMedida,
            ISNULL(s.lote, '') AS Lote,
            CAST(s.fecha_vence AS DATE) AS Fecha_Vence,
            SUM(s.Disponible_UMBas) AS Existencia_Sin_Estado_UMBas
        FROM dbo.VW_Stock_Res s
        WHERE s.IdBodega = @IdBodega
          AND s.IdPropietarioBodega = @IdPropietarioBodega
          AND (@IdProductoBodega IS NULL OR s.IdProductoBodega = @IdProductoBodega)
          AND (@Lote IS NULL OR ISNULL(s.lote,'') COLLATE DATABASE_DEFAULT = @Lote COLLATE DATABASE_DEFAULT)
          AND (
                @IncluirUbicacionesDespacho = 1
                OR s.IdUbicacion NOT IN (
                    SELECT bu.IdUbicacion
                    FROM dbo.bodega_ubicacion bu
                    WHERE bu.IdBodega = @IdBodega
                      AND bu.ubicacion_despacho = 1
                )
              )
        GROUP BY
            s.IdProductoBodega,
            ISNULL(s.IdPresentacion, 0),
            s.IdUnidadMedida,
            ISNULL(s.lote, ''),
            CAST(s.fecha_vence AS DATE)
    ),
    Prep AS (
        SELECT
            m.Codigo,
            m.Producto,
            m.Lote,
            m.EstadoOrigen AS Estado,
            m.Fecha_Vence AS Vence,
            m.IdProductoBodega,
            m.IdEstadoOrigen,
            m.IdPresentacion,
            m.IdUnidadMedida,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), m.Inventario_Inicial_UMBas / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), m.Inventario_Inicial_UMBas) END AS Inventario_Inicial,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), m.Ingresos_UMBas / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), m.Ingresos_UMBas) END AS Ingresos,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), m.AjustePositivo_UMBas / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), m.AjustePositivo_UMBas) END AS Ajustes_P,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), m.AjusteNegativo_UMBas / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), m.AjusteNegativo_UMBas) END AS Ajustes_N,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), m.Salidas_UMBas / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), m.Salidas_UMBas) END AS Salidas,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), ISNULL(sc.Existencia_Actual_UMBas, 0) / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), ISNULL(sc.Existencia_Actual_UMBas, 0)) END AS Existencia_Actual,
            CASE WHEN m.IdPresentacion <> 0 THEN CONVERT(DECIMAL(18,6), ISNULL(ss.Existencia_Sin_Estado_UMBas, 0) / NULLIF(ISNULL(pp.Factor, 1), 0))
                 ELSE CONVERT(DECIMAL(18,6), ISNULL(ss.Existencia_Sin_Estado_UMBas, 0)) END AS Existencia_Sin_Estado
        FROM MovBase m
        LEFT JOIN dbo.producto_presentacion pp
               ON pp.IdPresentacion = m.IdPresentacion
        LEFT JOIN SnapConEstado sc
               ON sc.IdProductoBodega = m.IdProductoBodega
              AND sc.IdEstadoOrigen = m.IdEstadoOrigen
              AND sc.IdPresentacion = m.IdPresentacion
              AND sc.IdUnidadMedida = m.IdUnidadMedida
              AND sc.Lote COLLATE DATABASE_DEFAULT = m.Lote COLLATE DATABASE_DEFAULT
              AND sc.Fecha_Vence = m.Fecha_Vence
        LEFT JOIN SnapSinEstado ss
               ON ss.IdProductoBodega = m.IdProductoBodega
              AND ss.IdPresentacion = m.IdPresentacion
              AND ss.IdUnidadMedida = m.IdUnidadMedida
              AND ss.Lote COLLATE DATABASE_DEFAULT = m.Lote COLLATE DATABASE_DEFAULT
              AND ss.Fecha_Vence = m.Fecha_Vence
    )
    SELECT
        p.Codigo,
        p.Producto AS Nombre,
        p.Lote,
        p.Estado,
        p.Vence,
        p.Inventario_Inicial,
        p.Ingresos,
        p.Ajustes_P,
        p.Ajustes_N,
        p.Salidas,
        CONVERT(DECIMAL(18,6), (p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas)) AS Existencia_Al,
        p.Existencia_Actual,
        CONVERT(DECIMAL(18,6),
            CASE
                WHEN ((p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas)) > 0
                    THEN p.Existencia_Actual - ((p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas))
                ELSE p.Existencia_Actual + ((p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas))
            END
            +
            CASE
                WHEN
                    (
                        CASE
                            WHEN ((p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas)) > 0
                                THEN p.Existencia_Actual - ((p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas))
                            ELSE p.Existencia_Actual + ((p.Inventario_Inicial + p.Ingresos + p.Ajustes_P) - (p.Ajustes_N + p.Salidas))
                        END
                    ) <> 0
                    AND (p.Existencia_Sin_Estado - p.Existencia_Actual) > 0
                THEN (p.Existencia_Sin_Estado - p.Existencia_Actual)
                ELSE 0
            END
        ) AS Diferencia,
        p.IdProductoBodega,
        p.IdEstadoOrigen,
        p.IdPresentacion,
        p.IdUnidadMedida
    FROM Prep p
    ORDER BY p.Codigo, p.Vence, p.Lote, p.Estado;
END
GO
