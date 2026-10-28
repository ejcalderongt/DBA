/*
  #EJC20260726_WEBAPI_REQUEST_TRACE
  Auditoria transversal y no intrusiva de requests de integracion WMS WebAPI.

  Contrato:
  - TraceId correlaciona request, respuesta, logs y documento procesado.
  - Las fechas son UTC del servidor; no dependen de fec_agr del payload.
  - RequestJson/ResponseJson permiten reproducir el intercambio original.
  - La escritura de auditoria se ejecuta fuera de la transaccion funcional.

  Rollback (solo si la retencion de auditoria ya no es requerida):
  DROP TABLE dbo.i_nav_webapi_request;
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.i_nav_webapi_request', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.i_nav_webapi_request
    (
        IdWebApiRequest bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_i_nav_webapi_request PRIMARY KEY,
        TraceId uniqueidentifier NOT NULL,
        FechaInicioUtc datetime2(3) NOT NULL
            CONSTRAINT DF_i_nav_webapi_request_FechaInicioUtc DEFAULT (SYSUTCDATETIME()),
        FechaFinUtc datetime2(3) NULL,
        Metodo varchar(10) NOT NULL,
        Endpoint nvarchar(500) NOT NULL,
        QueryString nvarchar(2000) NULL,
        ReferenciaDocumento nvarchar(100) NULL,
        RequestJson nvarchar(max) NULL,
        ResponseJson nvarchar(max) NULL,
        HttpStatus smallint NULL,
        Exito bit NULL,
        DuracionMs bigint NULL,
        MensajeError nvarchar(max) NULL,
        IpOrigen varchar(45) NULL,
        UserAgent nvarchar(500) NULL,
        ContentType nvarchar(200) NULL,
        RequestBytes bigint NULL,
        ResponseBytes bigint NULL,
        PayloadHash char(64) NULL,
        RequestTruncado bit NOT NULL
            CONSTRAINT DF_i_nav_webapi_request_RequestTruncado DEFAULT (0),
        ResponseTruncada bit NOT NULL
            CONSTRAINT DF_i_nav_webapi_request_ResponseTruncada DEFAULT (0),
        Hostname nvarchar(128) NULL,
        Ambiente nvarchar(50) NULL
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.i_nav_webapi_request')
      AND name = 'UX_i_nav_webapi_request_TraceId'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_i_nav_webapi_request_TraceId
        ON dbo.i_nav_webapi_request (TraceId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.i_nav_webapi_request')
      AND name = 'IX_i_nav_webapi_request_FechaInicioUtc'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_i_nav_webapi_request_FechaInicioUtc
        ON dbo.i_nav_webapi_request (FechaInicioUtc DESC)
        INCLUDE (TraceId, Metodo, Endpoint, ReferenciaDocumento, HttpStatus, Exito, DuracionMs);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.i_nav_webapi_request')
      AND name = 'IX_i_nav_webapi_request_ReferenciaDocumento'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_i_nav_webapi_request_ReferenciaDocumento
        ON dbo.i_nav_webapi_request (ReferenciaDocumento, FechaInicioUtc DESC)
        INCLUDE (TraceId, Endpoint, HttpStatus, Exito, DuracionMs)
        WHERE ReferenciaDocumento IS NOT NULL;
END;

COMMIT TRANSACTION;
