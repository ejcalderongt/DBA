/* SSMS: Ctrl+T antes de ejecutar. Consulta únicamente de lectura. */
USE IMS4MB_IDEALSA_PRD;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @Referencia nvarchar(100) = N'7809960';
DECLARE @IdBodega int = 16;

;WITH OC AS
(
    SELECT TOP (1)
        oc.IdOrdenCompraEnc,
        CONVERT(nvarchar(100), oc.Referencia) AS Referencia,
        oc.No_Documento,
        oc.IdBodega,
        oc.Fecha_Creacion,
        oc.IdEstadoOC
    FROM dbo.trans_oc_enc oc
    WHERE CONVERT(nvarchar(100), oc.Referencia) COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT
      AND oc.IdBodega = @IdBodega
    ORDER BY oc.IdOrdenCompraEnc DESC
),
Lineas AS
(
    SELECT
        oc.*,
        d.IdOrdenCompraDet,
        d.No_Linea,
        d.IdProductoBodega,
        pb.IdProducto,
        CONVERT(nvarchar(100), p.codigo) AS CodigoProducto,
        d.nombre_producto,
        d.IdPresentacion,
        d.nombre_presentacion,
        d.atributo_variante_1,
        d.nombre_unidad_medida_basica,
        d.cantidad,
        d.cantidad_recibida
    FROM OC oc
    INNER JOIN dbo.trans_oc_det d
        ON d.IdOrdenCompraEnc = oc.IdOrdenCompraEnc
    LEFT JOIN dbo.producto_bodega pb
        ON pb.IdProductoBodega = d.IdProductoBodega
    LEFT JOIN dbo.producto p
        ON p.IdProducto = pb.IdProducto
),
Presentacion AS
(
    SELECT
        l.IdOrdenCompraEnc,
        l.IdOrdenCompraDet,
        pp.IdPresentacion AS IdPresentacionMaestra,
        CONVERT(nvarchar(100), pp.codigo) AS CodigoPresentacionMaestra,
        CONVERT(nvarchar(100), pp.nombre) AS NombrePresentacionMaestra,
        pp.factor,
        pp.activo,
        ROW_NUMBER() OVER
        (
            PARTITION BY l.IdOrdenCompraEnc, l.IdOrdenCompraDet
            ORDER BY CASE WHEN pp.activo = 1 THEN 0 ELSE 1 END, pp.IdPresentacion DESC
        ) AS rn
    FROM Lineas l
    INNER JOIN dbo.producto_presentacion pp
        ON pp.IdProducto = l.IdProducto
       AND
       (
           pp.codigo COLLATE DATABASE_DEFAULT = l.atributo_variante_1 COLLATE DATABASE_DEFAULT
           OR pp.IdPresentacion = l.IdPresentacion
       )
),
Recepcion AS
(
    SELECT
        roc.IdOrdenCompraEnc,
        roc.IdRecepcionEnc,
        re.Estado AS EstadoRecepcion,
        ROW_NUMBER() OVER
        (
            PARTITION BY roc.IdOrdenCompraEnc
            ORDER BY roc.IdRecepcionEnc DESC
        ) AS rn
    FROM dbo.trans_re_oc roc
    INNER JOIN OC oc ON oc.IdOrdenCompraEnc = roc.IdOrdenCompraEnc
    LEFT JOIN dbo.trans_re_enc re ON re.IdRecepcionEnc = roc.IdRecepcionEnc
),
Tarea AS
(
    SELECT
        r.IdOrdenCompraEnc,
        r.IdRecepcionEnc,
        th.IdTareaHH,
        th.IdEstado AS EstadoTarea,
        th.IdTipoTarea,
        th.IdTransaccion,
        ROW_NUMBER() OVER
        (
            PARTITION BY r.IdOrdenCompraEnc
            ORDER BY th.IdTareaHH DESC
        ) AS rn
    FROM Recepcion r
    LEFT JOIN dbo.tarea_hh th
        ON th.IdTipoTarea = 1
       AND th.IdTransaccion = r.IdRecepcionEnc
    WHERE r.rn = 1
),
Trazas AS
(
    SELECT
        CONVERT(nvarchar(100), log.Referencia) AS Referencia,
        log.Fecha,
        CONVERT(nvarchar(max), log.[error]) AS Mensaje,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                CASE
                    WHEN log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=REQUEST_LINE_RECEIVED;%' THEN N'ENTRADA'
                    WHEN log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=WMS_LINE_PERSISTED;%' THEN N'PERSISTENCIA'
                    WHEN log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=TASK_ASSIGNMENT_%' THEN N'TAREA'
                    ELSE N'OTRA'
                END
            ORDER BY log.Fecha DESC
        ) AS rn,
        CASE
            WHEN log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=REQUEST_LINE_RECEIVED;%' THEN N'ENTRADA'
            WHEN log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=WMS_LINE_PERSISTED;%' THEN N'PERSISTENCIA'
            WHEN log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=TASK_ASSIGNMENT_%' THEN N'TAREA'
            ELSE N'OTRA'
        END AS TipoTraza
    FROM dbo.i_nav_ejecucion_det_error log
    WHERE CONVERT(nvarchar(100), log.Referencia) COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT
      AND log.[error] COLLATE DATABASE_DEFAULT LIKE N'%#EJC20260820_MI3_INGRESO_TRACE;%'
)
SELECT
    l.IdOrdenCompraEnc,
    l.Referencia,
    l.No_Documento,
    l.IdBodega,
    l.Fecha_Creacion,
    l.IdEstadoOC,
    l.No_Linea,
    l.IdOrdenCompraDet,
    l.IdProductoBodega,
    l.IdProducto,
    l.CodigoProducto,
    l.nombre_producto,
    mi3.No AS CodigoRecibidoMI3,
    mi3.Variant_Code AS VariantCodeRecibido,
    mi3.Unit_Of_Measure_Code AS UnidadRecibidaMI3,
    mi3.Quantity AS CantidadRecibidaMI3,
    l.IdPresentacion AS IdPresentacionGuardada,
    l.nombre_presentacion AS PresentacionGuardada,
    l.atributo_variante_1 AS VarianteGuardada,
    l.nombre_unidad_medida_basica AS UnidadGuardada,
    l.cantidad,
    l.cantidad_recibida,
    pp.IdPresentacionMaestra,
    pp.CodigoPresentacionMaestra,
    pp.NombrePresentacionMaestra,
    pp.factor,
    pp.activo AS PresentacionActiva,
    r.IdRecepcionEnc,
    r.EstadoRecepcion,
    t.IdTareaHH,
    t.EstadoTarea,
    (SELECT COUNT(1) FROM dbo.operador_bodega ob WHERE ob.IdBodega = l.IdBodega) AS OperadoresBodega,
    (SELECT COUNT(1) FROM dbo.trans_re_op rop WHERE rop.IdRecepcionEnc = r.IdRecepcionEnc) AS OperadoresAsignados,
    te.Fecha AS FechaTrazaEntrada,
    te.Mensaje AS TrazaEntrada,
    tp.Fecha AS FechaTrazaPersistencia,
    tp.Mensaje AS TrazaPersistencia,
    tt.Fecha AS FechaTrazaTarea,
    tt.Mensaje AS TrazaTarea,
    CASE
        WHEN l.IdPresentacion IS NULL OR l.IdPresentacion = 0 THEN N'ERROR_PRESENTACION_NO_GUARDADA'
        WHEN r.IdRecepcionEnc IS NULL THEN N'ERROR_RECEPCION_NO_GENERADA'
        WHEN t.IdTareaHH IS NULL THEN N'ERROR_TAREA_NO_GENERADA'
        WHEN (SELECT COUNT(1) FROM dbo.trans_re_op rop WHERE rop.IdRecepcionEnc = r.IdRecepcionEnc) = 0
            THEN N'ERROR_OPERADORES_NO_ASIGNADOS'
        ELSE N'OK'
    END AS Diagnostico
FROM Lineas l
LEFT JOIN dbo.i_nav_ped_compra_det mi3
    ON mi3.NoEnc COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
   AND mi3.Line_No = l.No_Linea
LEFT JOIN Presentacion pp
    ON pp.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND pp.IdOrdenCompraDet = l.IdOrdenCompraDet
   AND pp.rn = 1
LEFT JOIN Recepcion r
    ON r.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND r.rn = 1
LEFT JOIN Tarea t
    ON t.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND t.rn = 1
LEFT JOIN Trazas te ON te.TipoTraza = N'ENTRADA' AND te.rn = 1
LEFT JOIN Trazas tp ON tp.TipoTraza = N'PERSISTENCIA' AND tp.rn = 1
LEFT JOIN Trazas tt ON tt.TipoTraza = N'TAREA' AND tt.rn = 1
ORDER BY l.No_Linea;

