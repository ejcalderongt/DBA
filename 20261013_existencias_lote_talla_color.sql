/*
    #EJC20261013_EXISTENCIAS_LOTE_TALLA_COLOR

    Propósito:
      Llevar una base WMS antigua al contrato mínimo que necesita el reporte
      "Existencias por Lote" para mostrar talla y color sin depender de que
      VW_Stock_Res ya haya sido modernizada.

    Decisiones:
      - El script es idempotente: puede ejecutarse más de una vez.
      - No inventa tallas ni colores para el stock histórico.
      - Las relaciones nuevas quedan NULL hasta que exista información real.
      - El procedimiento une talla/color desde stock.IdProductoTallaColor.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.talla', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.talla
        (
            IdTalla       int            NOT NULL,
            Nombre        nvarchar(50)   NOT NULL,
            Descripcion   nvarchar(100)  NULL,
            IdPropietario int            NOT NULL,
            fec_agr       datetime       NOT NULL CONSTRAINT DF_talla_fec_agr DEFAULT (GETDATE()),
            user_agr      nvarchar(25)   NOT NULL,
            fec_mod       datetime       NULL,
            user_mod      nvarchar(25)   NULL,
            codigo        nvarchar(50)   NULL,
            activo        bit            NOT NULL CONSTRAINT DF_talla_activo DEFAULT (0),
            CONSTRAINT PK_talla PRIMARY KEY CLUSTERED (IdTalla)
        );
    END;

    IF OBJECT_ID(N'dbo.color', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.color
        (
            IdColor       int            NOT NULL,
            Nombre        nvarchar(50)   NOT NULL,
            CodigoHex     nvarchar(7)    NULL,
            IdPropietario int            NOT NULL,
            fec_agr       datetime       NOT NULL CONSTRAINT DF_color_fec_agr DEFAULT (GETDATE()),
            user_agr      nvarchar(25)   NOT NULL,
            fec_mod       datetime       NULL,
            user_mod      nvarchar(25)   NULL,
            codigo        nvarchar(50)   NULL,
            activo        bit            NOT NULL CONSTRAINT DF_color_activo DEFAULT (0),
            CONSTRAINT PK_color PRIMARY KEY CLUSTERED (IdColor)
        );
    END;

    IF OBJECT_ID(N'dbo.producto_talla_color', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.producto_talla_color
        (
            IdProductoTallaColor int            NOT NULL,
            IdProducto           int            NOT NULL,
            IdTalla              int            NOT NULL,
            IdColor              int            NOT NULL,
            IdCampaña            int            NULL,
            CodigoSKU            nvarchar(50)   NOT NULL,
            fec_agr              datetime       NOT NULL CONSTRAINT DF_producto_talla_color_fec_agr DEFAULT (GETDATE()),
            user_agr             nvarchar(25)   NOT NULL,
            fec_mod              datetime       NOT NULL CONSTRAINT DF_producto_talla_color_fec_mod DEFAULT (GETDATE()),
            user_mod             nvarchar(25)   NULL,
            activo               bit            NOT NULL CONSTRAINT DF_producto_talla_color_activo DEFAULT (1),
            CONSTRAINT PK_producto_talla_color PRIMARY KEY CLUSTERED (IdProductoTallaColor),
            CONSTRAINT UQ_producto_talla_color_CodigoSKU UNIQUE (CodigoSKU)
        );
    END;

    IF COL_LENGTH(N'dbo.stock', N'IdProductoTallaColor') IS NULL
        ALTER TABLE dbo.stock ADD IdProductoTallaColor int NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/*
    La carga optimizada devuelve los cuatro resultsets que consume la pantalla.
    Se apoya en la vista histórica para su contrato estable y agrega talla/color
    mediante LEFT JOIN; por eso una base sin variantes continúa funcionando.
*/
CREATE OR ALTER PROCEDURE dbo.sp_reporte_stock_por_lote_dataset
    @IdBodega int,
    @IdPropietarioBodega int,
    @ExcluirSinExistencia bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#detalle') IS NOT NULL
        DROP TABLE #detalle;

    ;WITH cte_pickeado AS
    (
        SELECT
            r.IdStock,
            SUM(u.cantidad_recibida) AS Cant_Pickeada
        FROM dbo.trans_picking_ubic u
        INNER JOIN dbo.trans_pe_enc e
            ON e.IdPedidoEnc = u.IdPedidoEnc
        RIGHT OUTER JOIN dbo.stock_res r
            ON u.IdStock = r.IdStock
           AND r.IdPedido = u.IdPedidoEnc
           AND r.IdPedidoDet = u.IdPedidoDet
        WHERE r.Indicador = 'PED'
          AND e.estado NOT IN ('Despachado', 'Anulado')
        GROUP BY r.IdStock
    )
    SELECT
        v.IdProducto,
        v.codigo,
        v.nombre AS Producto,
        v.NomEstado AS Estado,
        v.IdPresentacion,
        SUM(ISNULL(v.CantidadSF, 0)) AS CantidadUMBas,
        v.UnidadMedida,
        SUM(ISNULL(v.Cantidad_Presentacion, 0)) AS CantidadPresentacion,
        v.Presentacion,
        SUM(ISNULL(v.CantidadReservada, 0)) AS Cantidad_Reservada_UMBas,
        SUM(ISNULL(v.Cantidad_Reservada_Pres, 0)) AS Cantidad_Reservada_Pres,
        SUM(ISNULL(v.Disponible_UMBas, 0)) AS Disponible_UMBas,
        SUM(ISNULL(v.Disponible_Presentacion, 0)) AS Disponible_Presentación,
        v.peso AS Peso,
        v.lote AS Lote,
        v.lic_plate AS Licencia,
        v.fecha_ingreso AS Fecha_Ingreso,
        v.fecha_vence AS Fecha_Vence,
        v.Nombre_Completo AS Ubicacion,
        v.Codigo_Poliza,
        v.Numero_poliza AS numero_orden,
        v.ubicacion_picking,
        v.Area,
        v.factor,
        v.IdUbicacion,
        dbo.Nombre_Tramo(v.IdTramo, v.IdBodega) AS Tramo,
        CASE WHEN v.IdPresentacion IS NULL THEN ISNULL(p.Cant_Pickeada, 0) ELSE 0 END AS Cant_Pickeada_UMBas,
        CASE WHEN v.IdPresentacion IS NULL THEN v.CantidadReservadaUmBas - ISNULL(p.Cant_Pickeada, 0) ELSE 0 END AS Cant_No_Pickeada_UMBas,
        CASE WHEN v.IdPresentacion IS NOT NULL THEN ISNULL(p.Cant_Pickeada, 0) ELSE 0 END AS Cant_Pickeada_Presentacion,
        CASE WHEN v.IdPresentacion IS NOT NULL THEN v.Cantidad_Reservada_Pres - ISNULL(p.Cant_Pickeada, 0) ELSE 0 END AS Cant_No_Pickeada_Presentacion,
        ISNULL(t.codigo, N'') AS Talla,
        ISNULL(c.codigo, N'') AS Color,
        DATEDIFF(DAY, GETDATE(), v.fecha_vence) AS Vence_En
    INTO #detalle
    FROM dbo.VW_Stock_Res v
    INNER JOIN dbo.stock s
        ON s.IdStock = v.IdStock
    LEFT JOIN dbo.producto_talla_color ptc
        ON ptc.IdProductoTallaColor = s.IdProductoTallaColor
    LEFT JOIN dbo.talla t
        ON t.IdTalla = ptc.IdTalla
    LEFT JOIN dbo.color c
        ON c.IdColor = ptc.IdColor
    LEFT JOIN cte_pickeado p
        ON v.IdStock = p.IdStock
    WHERE (@IdBodega = 0 OR v.IdBodega = @IdBodega)
      AND (@IdPropietarioBodega = 0 OR v.IdPropietarioBodega = @IdPropietarioBodega)
    GROUP BY
        v.IdProducto, v.NomEstado, v.fecha_ingreso, v.codigo,
        v.nombre, v.Presentacion, v.IdPresentacion, v.UnidadMedida, v.peso,
        v.lote, v.fecha_vence, v.Nombre_Completo, v.lic_plate,
        v.factor, v.Codigo_Poliza, v.Numero_poliza, v.CantidadReservada,
        v.CantidadSF, v.ubicacion_picking, v.Area,
        v.IdUbicacion, v.IdTramo, v.IdBodega,
        t.codigo, c.codigo,
        p.Cant_Pickeada, v.CantidadReservadaUmBas, v.Cantidad_Reservada_Pres
    HAVING (@ExcluirSinExistencia = 0 OR SUM(ISNULL(v.Disponible_UMBas, 0)) > 0);

    SELECT *
    FROM #detalle
    ORDER BY codigo, Ubicacion;

    SELECT
        CASE
            WHEN Fecha_Vence IS NULL OR CONVERT(date, Fecha_Vence) = '19000101' THEN 'Sin vencimiento'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 15 THEN '0-15 dias'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 30 THEN '16-30 dias'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 60 THEN '31-60 dias'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 90 THEN '61-90 dias'
            ELSE '>90 dias'
        END AS Rango,
        CASE
            WHEN Fecha_Vence IS NULL OR CONVERT(date, Fecha_Vence) = '19000101' THEN 6
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 15 THEN 1
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 30 THEN 2
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 60 THEN 3
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 90 THEN 4
            ELSE 5
        END AS Orden,
        SUM(CASE WHEN IdPresentacion IS NULL THEN ISNULL(Disponible_UMBas, 0) ELSE ISNULL(Disponible_Presentación, 0) END) AS Stock
    FROM #detalle
    GROUP BY
        CASE
            WHEN Fecha_Vence IS NULL OR CONVERT(date, Fecha_Vence) = '19000101' THEN 'Sin vencimiento'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 15 THEN '0-15 dias'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 30 THEN '16-30 dias'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 60 THEN '31-60 dias'
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 90 THEN '61-90 dias'
            ELSE '>90 dias'
        END,
        CASE
            WHEN Fecha_Vence IS NULL OR CONVERT(date, Fecha_Vence) = '19000101' THEN 6
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 15 THEN 1
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 30 THEN 2
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 60 THEN 3
            WHEN DATEDIFF(DAY, CONVERT(date, GETDATE()), CONVERT(date, Fecha_Vence)) <= 90 THEN 4
            ELSE 5
        END
    ORDER BY Orden;

    SELECT TOP (20)
        codigo AS Codigo,
        SUM(CASE WHEN IdPresentacion IS NULL THEN ISNULL(Disponible_UMBas, 0) ELSE ISNULL(Disponible_Presentación, 0) END) AS Stock
    FROM #detalle
    GROUP BY codigo
    ORDER BY Stock DESC;

    SELECT
        CASE
            WHEN UPPER(ISNULL(Estado, '')) LIKE '%BUEN%'
              OR UPPER(ISNULL(Estado, '')) LIKE '%UTILIZABLE%'
            THEN 'Utilizable'
            ELSE 'No utilizable'
        END AS Categoria,
        SUM(ISNULL(Disponible_UMBas, 0)) AS Stock
    FROM #detalle
    GROUP BY
        CASE
            WHEN UPPER(ISNULL(Estado, '')) LIKE '%BUEN%'
              OR UPPER(ISNULL(Estado, '')) LIKE '%UTILIZABLE%'
            THEN 'Utilizable'
            ELSE 'No utilizable'
        END;
END;
GO

/* Validación corta y legible para el operador. */
SELECT
    CASE WHEN OBJECT_ID(N'dbo.talla', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TablaTalla,
    CASE WHEN OBJECT_ID(N'dbo.color', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TablaColor,
    CASE WHEN OBJECT_ID(N'dbo.producto_talla_color', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TablaProductoTallaColor,
    CASE WHEN COL_LENGTH(N'dbo.stock', N'IdProductoTallaColor') IS NOT NULL THEN 1 ELSE 0 END AS CampoStockTallaColor,
    CASE WHEN OBJECT_ID(N'dbo.sp_reporte_stock_por_lote_dataset', N'P') IS NOT NULL THEN 1 ELSE 0 END AS ProcedimientoReporte;
GO
