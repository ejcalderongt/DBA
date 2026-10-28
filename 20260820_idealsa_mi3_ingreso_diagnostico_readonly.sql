/*
    #EJC20260820_IDEALSA_MI3_INGRESO_DIAG_READONLY
    Consulta ad hoc: no crea SP, función, tabla permanente ni modifica datos.

    En SSMS:
      Ctrl+T       = Results to Text
      Ctrl+Shift+F = Results to File
*/

USE IMS4MB_IDEALSA_PRD;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdOrdenCompraEnc   int           = 33512;
DECLARE @IdTareaHH          int           = 26289;
DECLARE @IdBodega           int           = 16;
DECLARE @CodigoPresentacion nvarchar(100) = N'39002';
DECLARE @NombrePresentacion nvarchar(100) = N'UNIDAD';

;WITH Contexto AS
(
    SELECT
        oc.IdOrdenCompraEnc,
        CONVERT(nvarchar(100), oc.Referencia) AS Referencia,
        oc.No_Documento,
        oc.IdBodega,
        oc.Fecha_Creacion,
        ro.IdRecepcionEnc,
        re.Estado AS EstadoRecepcion,
        th.IdTareaHH,
        th.IdEstado AS EstadoTarea,
        th.IdTipoTarea,
        th.IdTransaccion AS IdTransaccionTarea
    FROM dbo.trans_oc_enc oc
    LEFT JOIN dbo.trans_re_oc ro
        ON ro.IdOrdenCompraEnc = oc.IdOrdenCompraEnc
    LEFT JOIN dbo.trans_re_enc re
        ON re.IdRecepcionEnc = ro.IdRecepcionEnc
    LEFT JOIN dbo.tarea_hh th
        ON th.IdTareaHH = @IdTareaHH
    WHERE oc.IdOrdenCompraEnc = @IdOrdenCompraEnc
),
Lineas AS
(
    SELECT
        c.*,
        od.IdOrdenCompraDet,
        od.No_Linea,
        od.IdProductoBodega,
        pb.IdProducto,
        CONVERT(nvarchar(100), p.Codigo) AS CodigoProductoWms,
        od.nombre_producto AS NombreProductoWms,
        od.IdPresentacion AS IdPresentacionGuardada,
        od.nombre_presentacion AS PresentacionGuardada,
        od.atributo_variante_1 AS VarianteGuardada,
        od.IdUnidadMedidaBasica,
        od.nombre_unidad_medida_basica AS UnidadGuardada,
        od.cantidad AS CantidadOC,
        od.cantidad_recibida AS CantidadRecibidaOC
    FROM Contexto c
    INNER JOIN dbo.trans_oc_det od
        ON od.IdOrdenCompraEnc = c.IdOrdenCompraEnc
    INNER JOIN dbo.producto_bodega pb
        ON pb.IdProductoBodega = od.IdProductoBodega
    INNER JOIN dbo.producto p
        ON p.IdProducto = pb.IdProducto
    WHERE @IdBodega IS NULL
       OR c.IdBodega = @IdBodega
       OR pb.IdBodega = @IdBodega
),
PresentacionesCandidatas AS
(
    SELECT
        l.IdOrdenCompraEnc,
        l.IdOrdenCompraDet,
        pp.IdPresentacion,
        pp.IdProducto,
        CONVERT(nvarchar(100), pp.codigo) AS CodigoPresentacion,
        CONVERT(nvarchar(100), pp.nombre) AS NombrePresentacion,
        pp.factor AS Factor,
        pp.activo AS Activo,
        CASE
            WHEN pp.codigo COLLATE DATABASE_DEFAULT = @CodigoPresentacion COLLATE DATABASE_DEFAULT
                THEN N'CODIGO_PARAMETRO'
            WHEN pp.codigo COLLATE DATABASE_DEFAULT = mi3.Variant_Code COLLATE DATABASE_DEFAULT
                THEN N'VARIANT_CODE'
            WHEN pp.nombre COLLATE DATABASE_DEFAULT = @NombrePresentacion COLLATE DATABASE_DEFAULT
                THEN N'NOMBRE_PARAMETRO'
            WHEN pp.nombre COLLATE DATABASE_DEFAULT = mi3.Unit_Of_Measure_Code COLLATE DATABASE_DEFAULT
                THEN N'UNIT_OF_MEASURE_CODE'
            ELSE N'SIN_COINCIDENCIA'
        END AS CriterioResolucion,
        ROW_NUMBER() OVER
        (
            PARTITION BY l.IdOrdenCompraEnc, l.IdOrdenCompraDet
            ORDER BY CASE WHEN pp.activo = 1 THEN 0 ELSE 1 END,
                     pp.IdPresentacion DESC
        ) AS rn
    FROM Lineas l
    LEFT JOIN dbo.i_nav_ped_compra_det mi3
        ON mi3.NoEnc COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
       AND mi3.Line_No = l.No_Linea
    INNER JOIN dbo.producto_presentacion pp
        ON pp.IdProducto = l.IdProducto
       AND
       (
           pp.codigo COLLATE DATABASE_DEFAULT = @CodigoPresentacion COLLATE DATABASE_DEFAULT
           OR pp.codigo COLLATE DATABASE_DEFAULT = mi3.Variant_Code COLLATE DATABASE_DEFAULT
           OR pp.nombre COLLATE DATABASE_DEFAULT = @NombrePresentacion COLLATE DATABASE_DEFAULT
           OR pp.nombre COLLATE DATABASE_DEFAULT = mi3.Unit_Of_Measure_Code COLLATE DATABASE_DEFAULT
       )
),
TrazaEntrada AS
(
    SELECT
        l.IdOrdenCompraEnc,
        l.IdOrdenCompraDet,
        log.Fecha,
        CONVERT(nvarchar(max), log.[error]) AS MensajeError,
        ROW_NUMBER() OVER
        (
            PARTITION BY l.IdOrdenCompraEnc, l.IdOrdenCompraDet
            ORDER BY log.Fecha DESC
        ) AS rn
    FROM Lineas l
    INNER JOIN dbo.i_nav_ejecucion_det_error log
        ON log.Referencia COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
       AND log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=REQUEST_LINE_RECEIVED;%'
       AND log.[error] COLLATE DATABASE_DEFAULT LIKE N'%LINEA=' + CONVERT(nvarchar(20), l.No_Linea) + N';%'
),
TrazaSalida AS
(
    SELECT
        l.IdOrdenCompraEnc,
        l.IdOrdenCompraDet,
        log.Fecha,
        CONVERT(nvarchar(max), log.[error]) AS MensajeError,
        ROW_NUMBER() OVER
        (
            PARTITION BY l.IdOrdenCompraEnc, l.IdOrdenCompraDet
            ORDER BY log.Fecha DESC
        ) AS rn
    FROM Lineas l
    INNER JOIN dbo.i_nav_ejecucion_det_error log
        ON log.Referencia COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
       AND log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EVENTO=WMS_LINE_PERSISTED;%'
       AND log.[error] COLLATE DATABASE_DEFAULT LIKE N'%LINEA=' + CONVERT(nvarchar(20), l.No_Linea) + N';%'
),
TrazaError AS
(
    SELECT
        l.IdOrdenCompraEnc,
        l.IdOrdenCompraDet,
        log.Fecha,
        CONVERT(nvarchar(max), log.[error]) AS MensajeError,
        ROW_NUMBER() OVER
        (
            PARTITION BY l.IdOrdenCompraEnc, l.IdOrdenCompraDet
            ORDER BY log.Fecha DESC
        ) AS rn
    FROM Lineas l
    INNER JOIN dbo.i_nav_ejecucion_det_error log
        ON log.Referencia COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
       AND
       (
           log.[error] COLLATE DATABASE_DEFAULT LIKE N'%EXCEPTION%'
           OR log.[error] COLLATE DATABASE_DEFAULT LIKE N'%REJECTED%'
           OR log.[error] COLLATE DATABASE_DEFAULT LIKE N'%FAILED%'
           OR log.[error] COLLATE DATABASE_DEFAULT LIKE N'%ERROR%'
       )
)
SELECT
    -- Contexto
    l.IdOrdenCompraEnc,
    l.IdRecepcionEnc,
    l.IdTareaHH,
    l.IdBodega,
    l.Referencia,
    l.No_Documento,
    l.Fecha_Creacion,
    l.EstadoRecepcion,
    l.EstadoTarea,
    l.IdTipoTarea,
    l.IdTransaccionTarea,

    -- Línea WMS
    l.No_Linea,
    l.IdOrdenCompraDet,
    l.IdProductoBodega,
    l.IdProducto,
    l.CodigoProductoWms,
    l.NombreProductoWms,
    l.IdPresentacionGuardada,
    l.PresentacionGuardada,
    l.VarianteGuardada,
    l.IdUnidadMedidaBasica,
    l.UnidadGuardada,
    l.CantidadOC,
    l.CantidadRecibidaOC,

    -- Petición MI3 intermedia
    mi3.NoEnc AS ReferenciaMI3,
    mi3.Line_No AS LineaMI3,
    mi3.No AS CodigoProductoRecibido,
    mi3.Variant_Code AS VariantCodeRecibido,
    mi3.Unit_Of_Measure_Code AS UnidadRecibida,
    mi3.Quantity AS CantidadRecibidaMI3,
    mi3.Quantity_Received AS CantidadProcesadaMI3,
    mi3.Location_Code AS BodegaDestinoRecibida,
    mi3.Barcode AS BarcodeRecibido,

    -- Presentación maestra
    pres.IdPresentacion AS IdPresentacionEsperada,
    pres.IdProducto AS IdProductoPresentacion,
    pres.CodigoPresentacion,
    pres.NombrePresentacion,
    pres.Factor,
    pres.Activo AS PresentacionActiva,
    pres.CriterioResolucion,

    -- Trazas disponibles después de desplegar la instrumentación
    trEntrada.Fecha AS FechaTrazaEntrada,
    trEntrada.MensajeError AS TrazaEntrada,
    trSalida.Fecha AS FechaTrazaPersistencia,
    trSalida.MensajeError AS TrazaPersistencia,
    trError.Fecha AS FechaUltimoError,
    trError.MensajeError AS UltimoError,

    -- Resultado listo para analizar
    CASE
        WHEN mi3.NoEnc IS NULL
            THEN N'01_SIN_LINEA_MI3'
        WHEN NULLIF(LTRIM(RTRIM(mi3.Variant_Code)), N'') IS NULL
            THEN N'02_VARIANT_CODE_VACIO'
        WHEN pres.IdPresentacion IS NULL
            THEN N'03_PRESENTACION_NO_RESUELTA'
        WHEN l.IdPresentacionGuardada IS NULL OR l.IdPresentacionGuardada = 0
            THEN N'04_IDPRESENTACION_NO_GUARDADO'
        WHEN pres.IdProducto <> l.IdProducto
            THEN N'05_PRESENTACION_OTRO_PRODUCTO'
        WHEN l.IdPresentacionGuardada <> pres.IdPresentacion
            THEN N'06_PRESENTACION_DIFERENTE'
        WHEN NULLIF(LTRIM(RTRIM(l.VarianteGuardada)), N'') IS NULL
            THEN N'07_VARIANTE_NO_COPIADA'
        ELSE N'00_OK'
    END AS Diagnostico,
    CASE
        WHEN mi3.NoEnc IS NULL
            THEN N'No se encontró i_nav_ped_compra_det por referencia y línea.'
        WHEN NULLIF(LTRIM(RTRIM(mi3.Variant_Code)), N'') IS NULL
            THEN N'El ERP no envió Variant_Code o WCF no lo deserializó.'
        WHEN pres.IdPresentacion IS NULL
            THEN N'No existe producto_presentacion compatible para este producto.'
        WHEN l.IdPresentacionGuardada IS NULL OR l.IdPresentacionGuardada = 0
            THEN N'El dato llegó, pero Procesar_Pedido_Compra_MI3 no asignó IdPresentacion.'
        ELSE N'Comparar entrada, maestro y persistencia mostrados en esta fila.'
    END AS Interpretacion
FROM Lineas l
LEFT JOIN dbo.i_nav_ped_compra_det mi3
    ON mi3.NoEnc COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
   AND mi3.Line_No = l.No_Linea
LEFT JOIN PresentacionesCandidatas pres
    ON pres.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND pres.IdOrdenCompraDet = l.IdOrdenCompraDet
   AND pres.rn = 1
LEFT JOIN TrazaEntrada trEntrada
    ON trEntrada.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND trEntrada.IdOrdenCompraDet = l.IdOrdenCompraDet
   AND trEntrada.rn = 1
LEFT JOIN TrazaSalida trSalida
    ON trSalida.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND trSalida.IdOrdenCompraDet = l.IdOrdenCompraDet
   AND trSalida.rn = 1
LEFT JOIN TrazaError trError
    ON trError.IdOrdenCompraEnc = l.IdOrdenCompraEnc
   AND trError.IdOrdenCompraDet = l.IdOrdenCompraDet
   AND trError.rn = 1
ORDER BY l.No_Linea;
