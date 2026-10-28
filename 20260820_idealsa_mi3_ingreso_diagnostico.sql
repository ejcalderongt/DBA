/*
    #EJC20260820_IDEALSA_MI3_INGRESO_DIAG

    Diagnóstico read-only de documento de ingreso MI3:
    request/interfaz -> OC WMS -> presentación maestra -> recepción/tarea -> trazas.

    El procedimiento no modifica datos operativos. Devuelve un único result set,
    una fila por detalle de orden de compra.
*/

CREATE OR ALTER PROCEDURE dbo.usp_wms_mi3_ingreso_diagnostico
    @IdOrdenCompraEnc   int           = NULL,
    @IdRecepcionEnc     int           = NULL,
    @IdTareaHH          int           = NULL,
    @IdBodega           int           = NULL,
    @CodigoProducto     nvarchar(100) = NULL,
    @CodigoPresentacion nvarchar(100) = NULL,
    @NombrePresentacion nvarchar(100) = NULL,
    @Referencia         nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @OcResuelta int = @IdOrdenCompraEnc;
    DECLARE @RecResuelta int = @IdRecepcionEnc;
    DECLARE @ReferenciaResuelta nvarchar(100) = NULLIF(LTRIM(RTRIM(@Referencia)), N'');

    IF @RecResuelta IS NULL AND @IdTareaHH IS NOT NULL
    BEGIN
        SELECT TOP (1) @RecResuelta = th.IdTransaccion
        FROM dbo.tarea_hh th
        WHERE th.IdTareaHH = @IdTareaHH;
    END;

    IF @OcResuelta IS NULL AND @RecResuelta IS NOT NULL
    BEGIN
        SELECT TOP (1) @OcResuelta = ro.IdOrdenCompraEnc
        FROM dbo.trans_re_oc ro
        WHERE ro.IdRecepcionEnc = @RecResuelta
        ORDER BY ro.IdOrdenCompraEnc DESC;
    END;

    IF @OcResuelta IS NULL AND @ReferenciaResuelta IS NOT NULL
    BEGIN
        SELECT TOP (1) @OcResuelta = oc.IdOrdenCompraEnc
        FROM dbo.trans_oc_enc oc
        WHERE oc.Referencia COLLATE DATABASE_DEFAULT = @ReferenciaResuelta COLLATE DATABASE_DEFAULT
        ORDER BY oc.IdOrdenCompraEnc DESC;
    END;

    IF @OcResuelta IS NULL
        THROW 50001, 'No fue posible resolver IdOrdenCompraEnc con los parámetros recibidos.', 1;

    SELECT TOP (1)
        @ReferenciaResuelta = CONVERT(nvarchar(100), oc.Referencia)
    FROM dbo.trans_oc_enc oc
    WHERE oc.IdOrdenCompraEnc = @OcResuelta;

    IF @RecResuelta IS NULL
    BEGIN
        SELECT TOP (1) @RecResuelta = ro.IdRecepcionEnc
        FROM dbo.trans_re_oc ro
        WHERE ro.IdOrdenCompraEnc = @OcResuelta
        ORDER BY ro.IdRecepcionEnc DESC;
    END;

    CREATE TABLE #Traza
    (
        Fecha                 datetime        NULL,
        Referencia            nvarchar(100)   NULL,
        NoLinea               int             NULL,
        CodigoProducto        nvarchar(100)   NULL,
        UnidadMedida          nvarchar(100)   NULL,
        CodigoPresentacion    nvarchar(100)   NULL,
        Nivel                 nvarchar(30)    NULL,
        HumanError            nvarchar(1000)  NULL,
        TrazaTecnica          nvarchar(max)   NULL
    );

    IF OBJECT_ID(N'dbo.i_nav_ejecucion_det_error', N'U') IS NOT NULL
    BEGIN
        DECLARE @SqlTraza nvarchar(max) = N'
            INSERT INTO #Traza
            (
                Fecha, Referencia, NoLinea, CodigoProducto, UnidadMedida,
                CodigoPresentacion, Nivel, HumanError, TrazaTecnica
            )
            SELECT
                Fecha,
                CONVERT(nvarchar(100), Referencia),
                ' + CASE WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'No_Linea') IS NOT NULL
                         THEN N'No_Linea' ELSE N'NULL' END + N',
                ' + CASE WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'Codigo_Producto') IS NOT NULL
                         THEN N'CONVERT(nvarchar(100), Codigo_Producto)' ELSE N'NULL' END + N',
                ' + CASE WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'UMBas') IS NOT NULL
                         THEN N'CONVERT(nvarchar(100), UMBas)' ELSE N'NULL' END + N',
                ' + CASE WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'Codigo_Presentacion') IS NOT NULL
                         THEN N'CONVERT(nvarchar(100), Codigo_Presentacion)' ELSE N'NULL' END + N',
                ' + CASE WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'LevelLog') IS NOT NULL
                         THEN N'CONVERT(nvarchar(30), LevelLog)'
                         WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'level_log') IS NOT NULL
                         THEN N'CONVERT(nvarchar(30), level_log)' ELSE N'NULL' END + N',
                ' + CASE WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'HumanError') IS NOT NULL
                         THEN N'CONVERT(nvarchar(1000), HumanError)'
                         WHEN COL_LENGTH('dbo.i_nav_ejecucion_det_error', 'human_error') IS NOT NULL
                         THEN N'CONVERT(nvarchar(1000), human_error)' ELSE N'NULL' END + N',
                CONVERT(nvarchar(max), [error])
            FROM dbo.i_nav_ejecucion_det_error
            WHERE Referencia COLLATE DATABASE_DEFAULT = @pReferencia COLLATE DATABASE_DEFAULT
               OR [error] COLLATE DATABASE_DEFAULT LIKE N''%ID_ORDEN_COMPRA_ENC='' + CONVERT(nvarchar(20), @pOc) + N''%'';';

        EXEC sys.sp_executesql
            @SqlTraza,
            N'@pReferencia nvarchar(100), @pOc int',
            @pReferencia = @ReferenciaResuelta,
            @pOc = @OcResuelta;
    END;

    ;WITH Lineas AS
    (
        SELECT
            oc.IdOrdenCompraEnc,
            oc.No_Documento,
            CONVERT(nvarchar(100), oc.Referencia) AS Referencia,
            oc.IdBodega,
            oc.IdEstadoOC,
            oc.Activo AS OcActiva,
            oc.Fecha_Creacion,
            od.IdOrdenCompraDet,
            od.No_Linea,
            od.IdProductoBodega,
            pb.IdProducto,
            CONVERT(nvarchar(100), p.Codigo) AS CodigoProductoWms,
            od.nombre_producto,
            od.IdPresentacion AS IdPresentacionGuardada,
            od.nombre_presentacion AS PresentacionGuardada,
            od.atributo_variante_1 AS VarianteGuardada,
            od.IdUnidadMedidaBasica,
            od.nombre_unidad_medida_basica AS UnidadGuardada,
            od.cantidad,
            od.cantidad_recibida
        FROM dbo.trans_oc_enc oc
        INNER JOIN dbo.trans_oc_det od
            ON od.IdOrdenCompraEnc = oc.IdOrdenCompraEnc
        INNER JOIN dbo.producto_bodega pb
            ON pb.IdProductoBodega = od.IdProductoBodega
        INNER JOIN dbo.producto p
            ON p.IdProducto = pb.IdProducto
        WHERE oc.IdOrdenCompraEnc = @OcResuelta
          AND (@IdBodega IS NULL OR oc.IdBodega = @IdBodega OR pb.IdBodega = @IdBodega)
          AND
          (
              NULLIF(LTRIM(RTRIM(@CodigoProducto)), N'') IS NULL
              OR p.Codigo COLLATE DATABASE_DEFAULT = @CodigoProducto COLLATE DATABASE_DEFAULT
          )
    )
    SELECT
        -- Identidad operativa
        l.IdOrdenCompraEnc,
        @RecResuelta AS IdRecepcionEnc,
        @IdTareaHH AS IdTareaHHSolicitada,
        th.IdTareaHH AS IdTareaHHEncontrada,
        l.IdBodega,
        re.Estado AS EstadoRecepcion,
        th.IdEstado AS EstadoTarea,
        th.IdTipoTarea,
        th.IdTransaccion AS IdTransaccionTarea,
        l.Referencia,
        l.No_Documento,
        l.Fecha_Creacion,

        -- Línea recibida por MI3
        l.No_Linea,
        l.IdOrdenCompraDet,
        l.IdProductoBodega,
        l.IdProducto,
        l.CodigoProductoWms,
        l.nombre_producto AS NombreProductoWms,
        mi3.No AS CodigoProductoRecibido,
        mi3.Variant_Code AS VariantCodeRecibido,
        mi3.Unit_Of_Measure_Code AS UnidadRecibida,
        mi3.Quantity AS CantidadRecibidaMI3,
        mi3.Quantity_Received AS CantidadProcesadaMI3,
        mi3.Barcode AS BarcodeRecibido,

        -- Resultado persistido en WMS
        l.IdPresentacionGuardada,
        l.PresentacionGuardada,
        l.VarianteGuardada,
        l.IdUnidadMedidaBasica,
        l.UnidadGuardada,
        l.cantidad AS CantidadOC,
        l.cantidad_recibida AS CantidadRecibidaOC,

        -- Presentación maestra candidata
        pres.IdPresentacion AS IdPresentacionEsperada,
        pres.IdProducto AS IdProductoPresentacion,
        pres.CodigoPresentacion,
        pres.NombrePresentacion,
        pres.FactorPresentacion,
        pres.PresentacionActiva,
        pres.CriterioResolucionPresentacion,

        -- Últimas trazas correlacionadas
        trEntrada.Fecha AS FechaTrazaEntrada,
        trEntrada.CodigoPresentacion AS CodigoPresentacionTrazaEntrada,
        trEntrada.UnidadMedida AS UnidadTrazaEntrada,
        trEntrada.TrazaTecnica AS TrazaEntrada,
        trSalida.Fecha AS FechaTrazaPersistencia,
        trSalida.CodigoPresentacion AS PresentacionTrazaPersistencia,
        trSalida.TrazaTecnica AS TrazaPersistencia,
        trError.Fecha AS FechaUltimoError,
        trError.Nivel AS NivelUltimoError,
        trError.HumanError AS UltimoErrorHumano,
        trError.TrazaTecnica AS UltimoErrorTecnico,

        -- Diagnóstico consolidado
        CASE
            WHEN mi3.NoEnc IS NULL
                THEN N'01_SIN_LINEA_MI3: no se encontró la petición intermedia por referencia y línea.'
            WHEN NULLIF(LTRIM(RTRIM(mi3.Variant_Code)), N'') IS NULL
                THEN N'02_VARIANT_CODE_VACIO: la petición no contiene código de variante/presentación.'
            WHEN pres.IdPresentacion IS NULL
                THEN N'03_PRESENTACION_NO_RESUELTA: no existe presentación maestra compatible para el producto.'
            WHEN l.IdPresentacionGuardada IS NULL OR l.IdPresentacionGuardada = 0
                THEN N'04_IDPRESENTACION_NO_GUARDADO: MI3 recibió datos, pero trans_oc_det quedó sin presentación.'
            WHEN pres.IdProducto <> l.IdProducto
                THEN N'05_PRESENTACION_OTRO_PRODUCTO: la presentación candidata pertenece a otro producto.'
            WHEN l.IdPresentacionGuardada <> pres.IdPresentacion
                THEN N'06_PRESENTACION_DIFERENTE: WMS guardó una presentación distinta de la resuelta.'
            WHEN NULLIF(LTRIM(RTRIM(l.VarianteGuardada)), N'') IS NULL
                THEN N'07_VARIANTE_NO_COPIADA: IdPresentacion existe, pero atributo_variante_1 quedó vacío.'
            ELSE N'00_OK: petición, maestro y persistencia son coherentes.'
        END AS Diagnostico,
        CASE
            WHEN mi3.NoEnc IS NULL THEN N'Revisar deserialización y persistencia de i_nav_ped_compra_det.'
            WHEN NULLIF(LTRIM(RTRIM(mi3.Variant_Code)), N'') IS NULL THEN N'Confirmar que el ERP envíe Variant_Code, no CodVariante.'
            WHEN pres.IdPresentacion IS NULL THEN N'Validar producto_presentacion por IdProducto + código/nombre recibido.'
            WHEN l.IdPresentacionGuardada IS NULL OR l.IdPresentacionGuardada = 0 THEN N'Revisar ValidarPresentaciones/CrearYGuardarDetalleOC en Procesar_Pedido_Compra_MI3.'
            ELSE N'Comparar REQUEST_LINE_RECEIVED contra WMS_LINE_PERSISTED usando TraceId.'
        END AS SiguientePaso
    FROM Lineas l
    LEFT JOIN dbo.trans_re_enc re
        ON re.IdRecepcionEnc = @RecResuelta
    LEFT JOIN dbo.tarea_hh th
        ON (@IdTareaHH IS NOT NULL AND th.IdTareaHH = @IdTareaHH)
        OR (@IdTareaHH IS NULL AND th.IdTransaccion = @RecResuelta)
    LEFT JOIN dbo.i_nav_ped_compra_det mi3
        ON mi3.NoEnc COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
       AND mi3.Line_No = l.No_Linea
    OUTER APPLY
    (
        SELECT TOP (1)
            pp.IdPresentacion,
            pp.IdProducto,
            CONVERT(nvarchar(100), pp.codigo) AS CodigoPresentacion,
            CONVERT(nvarchar(100), pp.nombre) AS NombrePresentacion,
            pp.factor AS FactorPresentacion,
            pp.activo AS PresentacionActiva,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(@CodigoPresentacion)), N'') IS NOT NULL
                     AND pp.codigo COLLATE DATABASE_DEFAULT = @CodigoPresentacion COLLATE DATABASE_DEFAULT
                    THEN N'CODIGO_PARAMETRO'
                WHEN NULLIF(LTRIM(RTRIM(mi3.Variant_Code)), N'') IS NOT NULL
                     AND pp.codigo COLLATE DATABASE_DEFAULT = mi3.Variant_Code COLLATE DATABASE_DEFAULT
                    THEN N'VARIANT_CODE'
                WHEN NULLIF(LTRIM(RTRIM(@NombrePresentacion)), N'') IS NOT NULL
                     AND pp.nombre COLLATE DATABASE_DEFAULT = @NombrePresentacion COLLATE DATABASE_DEFAULT
                    THEN N'NOMBRE_PARAMETRO'
                WHEN NULLIF(LTRIM(RTRIM(mi3.Unit_Of_Measure_Code)), N'') IS NOT NULL
                     AND pp.nombre COLLATE DATABASE_DEFAULT = mi3.Unit_Of_Measure_Code COLLATE DATABASE_DEFAULT
                    THEN N'UNIT_OF_MEASURE_CODE'
                ELSE N'SIN_COINCIDENCIA_EXACTA'
            END AS CriterioResolucionPresentacion
        FROM dbo.producto_presentacion pp
        WHERE pp.IdProducto = l.IdProducto
          AND
          (
              (NULLIF(LTRIM(RTRIM(@CodigoPresentacion)), N'') IS NOT NULL
               AND pp.codigo COLLATE DATABASE_DEFAULT = @CodigoPresentacion COLLATE DATABASE_DEFAULT)
              OR
              (NULLIF(LTRIM(RTRIM(mi3.Variant_Code)), N'') IS NOT NULL
               AND pp.codigo COLLATE DATABASE_DEFAULT = mi3.Variant_Code COLLATE DATABASE_DEFAULT)
              OR
              (NULLIF(LTRIM(RTRIM(@NombrePresentacion)), N'') IS NOT NULL
               AND pp.nombre COLLATE DATABASE_DEFAULT = @NombrePresentacion COLLATE DATABASE_DEFAULT)
              OR
              (NULLIF(LTRIM(RTRIM(mi3.Unit_Of_Measure_Code)), N'') IS NOT NULL
               AND pp.nombre COLLATE DATABASE_DEFAULT = mi3.Unit_Of_Measure_Code COLLATE DATABASE_DEFAULT)
          )
        ORDER BY
            CASE WHEN pp.activo = 1 THEN 0 ELSE 1 END,
            pp.IdPresentacion DESC
    ) pres
    OUTER APPLY
    (
        SELECT TOP (1) t.*
        FROM #Traza t
        WHERE t.Referencia COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
          AND (t.NoLinea = l.No_Linea OR ISNULL(t.NoLinea, 0) = 0)
          AND
          (
              t.TrazaTecnica LIKE N'%EVENTO=REQUEST_LINE_RECEIVED;%'
              OR t.TrazaTecnica LIKE N'%EVENTO=UPDATE_REQUEST_LINE_RECEIVED;%'
          )
        ORDER BY t.Fecha DESC
    ) trEntrada
    OUTER APPLY
    (
        SELECT TOP (1) t.*
        FROM #Traza t
        WHERE t.Referencia COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
          AND (t.NoLinea = l.No_Linea OR ISNULL(t.NoLinea, 0) = 0)
          AND t.TrazaTecnica LIKE N'%EVENTO=WMS_LINE_PERSISTED;%'
        ORDER BY t.Fecha DESC
    ) trSalida
    OUTER APPLY
    (
        SELECT TOP (1) t.*
        FROM #Traza t
        WHERE t.Referencia COLLATE DATABASE_DEFAULT = l.Referencia COLLATE DATABASE_DEFAULT
          AND
          (
              t.Nivel IN (N'ERROR', N'WARN')
              OR t.TrazaTecnica LIKE N'%EXCEPTION%'
              OR t.TrazaTecnica LIKE N'%REJECTED%'
              OR t.TrazaTecnica LIKE N'%FAILED%'
          )
        ORDER BY t.Fecha DESC
    ) trError
    ORDER BY l.No_Linea;
END;
GO

/*
Caso IDEALSA observado el 2026-08-20:

EXEC dbo.usp_wms_mi3_ingreso_diagnostico
    @IdOrdenCompraEnc   = 33512,
    @IdTareaHH          = 26289,
    @IdBodega           = 16,
    @CodigoProducto     = NULL,
    @CodigoPresentacion = N'39002',
    @NombrePresentacion = N'UNIDAD';
*/
