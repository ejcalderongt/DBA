/*
  #EJC20260721_MI3_UPDATE_RECONCILIACION_EXPEDITA
  Correlaciona en la bitacora existente todas las modificaciones solicitadas
  por una misma llamada de POST /api/sync/salidas/mi3/update.

  Rollback (solo si no existen consumidores del campo):
  ALTER TABLE dbo.trans_pe_det_log_reserva DROP COLUMN TraceToken;
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH('dbo.trans_pe_det_log_reserva', 'TraceToken') IS NULL
BEGIN
    ALTER TABLE dbo.trans_pe_det_log_reserva
        ADD TraceToken nvarchar(64) NULL;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.trans_pe_det_log_reserva')
      AND name = 'IX_trans_pe_det_log_reserva_TraceToken'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trans_pe_det_log_reserva_TraceToken
        ON dbo.trans_pe_det_log_reserva (TraceToken)
        INCLUDE (IdPedidoEnc, IdPedidoDet, Fecha, Caso_Reserva, EsError);
END;

COMMIT TRANSACTION;
