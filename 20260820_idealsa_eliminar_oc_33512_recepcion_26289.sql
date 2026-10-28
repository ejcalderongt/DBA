/*
    #EJC20260820_IDEALSA_REPLAY_OC_33512

    Elimina exclusivamente la OC WMS 33512, su recepción automática 26289,
    su tarea de recepción y las filas intermedias de la referencia 7809960.

    SEGURIDAD:
      - Valida Id, referencia, bodega y recepción esperada.
      - Se detiene si ya existe recepción física, stock o movimientos.
      - ROLLBACK por defecto. Cambiar @AplicarCambios a 1 únicamente después
        de revisar los result sets de PRECHECK.
*/

USE IMS4MB_IDEALSA_PRD;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @AplicarCambios       bit           = 0; -- 0=simulación, 1=COMMIT
DECLARE @IdOrdenCompraEnc     int           = 33512;
DECLARE @IdRecepcionEnc       int           = 26289;
DECLARE @IdBodega             int           = 16;
DECLARE @Referencia           nvarchar(100) = N'7809960';

BEGIN TRY
    BEGIN TRANSACTION;

    /* PRECHECK: identidad exacta del documento. */
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.trans_oc_enc WITH (UPDLOCK, HOLDLOCK)
        WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc
          AND CONVERT(nvarchar(100), Referencia) COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT
          AND IdBodega = @IdBodega
    )
        THROW 51000, 'ABORTADO: la OC no coincide con Id=33512, referencia=7809960 y bodega=16.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.trans_re_oc WITH (UPDLOCK, HOLDLOCK)
        WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc
          AND IdRecepcionEnc = @IdRecepcionEnc
    )
        THROW 51001, 'ABORTADO: la recepción 26289 no está relacionada con la OC 33512.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.trans_re_oc
        WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc
          AND IdRecepcionEnc <> @IdRecepcionEnc
    )
        THROW 51002, 'ABORTADO: la OC tiene otra recepción adicional; se requiere revisión manual.', 1;

    /* No borrar documentos que ya tengan operación física. */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.trans_oc_det
        WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc
          AND ISNULL(cantidad_recibida, 0) <> 0
    )
        THROW 51003, 'ABORTADO: la OC tiene cantidad recibida.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.trans_re_det
        WHERE IdRecepcionEnc = @IdRecepcionEnc
          AND ISNULL(cantidad_recibida, 0) <> 0
    )
        THROW 51004, 'ABORTADO: la recepción tiene detalle físicamente recibido.', 1;

    IF OBJECT_ID(N'dbo.stock', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.stock WHERE IdRecepcionEnc = @IdRecepcionEnc)
        THROW 51005, 'ABORTADO: existe stock relacionado con la recepción.', 1;

    IF OBJECT_ID(N'dbo.trans_movimientos', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.trans_movimientos WHERE IdRecepcion = @IdRecepcionEnc)
        THROW 51006, 'ABORTADO: existen movimientos relacionados con la recepción.', 1;

    /* Resultado de control antes de eliminar. */
    SELECT N'PRECHECK_OC' AS Seccion, *
    FROM dbo.trans_oc_enc
    WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc;

    SELECT N'PRECHECK_RECEPCION' AS Seccion, re.*
    FROM dbo.trans_re_enc re
    WHERE re.IdRecepcionEnc = @IdRecepcionEnc;

    SELECT
        N'PRECHECK_CONTEOS' AS Seccion,
        (SELECT COUNT(1) FROM dbo.trans_oc_det WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc) AS DetallesOC,
        (SELECT COUNT(1) FROM dbo.trans_re_det WHERE IdRecepcionEnc = @IdRecepcionEnc) AS DetallesRecepcion,
        (SELECT COUNT(1) FROM dbo.trans_re_op WHERE IdRecepcionEnc = @IdRecepcionEnc) AS OperadoresRecepcion,
        (SELECT COUNT(1) FROM dbo.tarea_hh WHERE IdTipoTarea = 1 AND IdTransaccion = @IdRecepcionEnc) AS TareasRecepcion;

    /* Dependencias de la recepción. */
    DELETE FROM dbo.tarea_hh
    WHERE IdTipoTarea = 1
      AND IdTransaccion = @IdRecepcionEnc;

    DELETE FROM dbo.trans_re_det_parametros WHERE IdRecepcionEnc = @IdRecepcionEnc;
    DELETE FROM dbo.trans_re_det_infraccion WHERE IdRecepcionEnc = @IdRecepcionEnc;
    DELETE FROM dbo.trans_re_op WHERE IdRecepcionEnc = @IdRecepcionEnc;
    DELETE FROM dbo.trans_re_img WHERE IdRecepcionEnc = @IdRecepcionEnc;
    DELETE FROM dbo.trans_re_fact WHERE IdRecepcionEnc = @IdRecepcionEnc;
    /* trans_re_tr es catálogo de tipos de recepción; nunca se elimina. */
    DELETE FROM dbo.trans_re_det WHERE IdRecepcionEnc = @IdRecepcionEnc;
    DELETE FROM dbo.trans_re_oc
    WHERE IdRecepcionEnc = @IdRecepcionEnc
      AND IdOrdenCompraEnc = @IdOrdenCompraEnc;
    DELETE FROM dbo.trans_re_enc WHERE IdRecepcionEnc = @IdRecepcionEnc;

    /* Dependencias de la orden de compra. */
    DELETE FROM dbo.trans_oc_imagen WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc;
    DELETE FROM dbo.trans_oc_servicios WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc;
    DELETE FROM dbo.trans_oc_pol WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc;
    DELETE FROM dbo.trans_oc_det_lote WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc;
    DELETE FROM dbo.trans_oc_det WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc;
    DELETE FROM dbo.trans_oc_enc
    WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc
      AND CONVERT(nvarchar(100), Referencia) COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT
      AND IdBodega = @IdBodega;

    /* Copia intermedia de la misma OC: necesaria para permitir el replay MI3. */
    DELETE FROM dbo.i_nav_ped_compra_det
    WHERE NoEnc COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT;

    DELETE FROM dbo.i_nav_ped_compra_enc
    WHERE No COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT;

    SELECT
        N'POST_DELETE_DENTRO_TRANSACCION' AS Seccion,
        (SELECT COUNT(1) FROM dbo.trans_oc_enc WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc) AS OcRestante,
        (SELECT COUNT(1) FROM dbo.trans_re_enc WHERE IdRecepcionEnc = @IdRecepcionEnc) AS RecepcionRestante,
        (SELECT COUNT(1) FROM dbo.trans_re_oc WHERE IdOrdenCompraEnc = @IdOrdenCompraEnc) AS VinculosRestantes,
        (SELECT COUNT(1) FROM dbo.tarea_hh WHERE IdTipoTarea = 1 AND IdTransaccion = @IdRecepcionEnc) AS TareasRestantes,
        (SELECT COUNT(1) FROM dbo.trans_re_op WHERE IdRecepcionEnc = @IdRecepcionEnc) AS OperadoresRestantes,
        (SELECT COUNT(1) FROM dbo.i_nav_ped_compra_enc WHERE No COLLATE DATABASE_DEFAULT = @Referencia COLLATE DATABASE_DEFAULT) AS IntermediaRestante;

    IF @AplicarCambios = 1
    BEGIN
        COMMIT TRANSACTION;
        SELECT N'COMMIT_APLICADO' AS Resultado;
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT N'SIMULACION_ROLLBACK_SIN_CAMBIOS' AS Resultado;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
