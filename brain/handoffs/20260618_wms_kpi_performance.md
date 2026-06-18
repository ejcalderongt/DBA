# WMS KPI Performance Handoff

## Context

- The WMS KPI API published on `8091` needed a performance pass.
- `picking` was the main slow endpoint at about 26 seconds for a month range.
- `despacho` also needed query-level tightening because it repeated several scans over `trans_picking_ubic`.

## What Changed

- `WMSWebAPI/Services/KPI/KpiReportService.cs` now filters `picking` from a `BasePicking` CTE before the main join tree.
- `despacho` now uses CTEs for the base dispatch rows, cleaned picking rows, flag aggregation, packing lookup, and `MAX(fec_agr)` per dispatch.
- `tendencias` and `heatmap` no longer cast `fec_agr` to `date` in the predicate, keeping the predicate sargable.

## Database Script

- Added `20260618_kpi_performance_indexes.sql` at the repo root.
- The script adds:
  - `IX_trans_picking_ubic_kpi_clean_fecha`
  - `IX_trans_despacho_det_kpi_fecagr`
  - `IX_trans_pe_enc_kpi_fechapedido`
- Added follow-up indexes for the remaining slow paths:
  - `IX_trans_despacho_enc_kpi_fecha` on `dbo.trans_despacho_enc(fecha, IdDespachoEnc)`
  - `IX_trans_picking_ubic_kpi_verificacion_fecha` on `dbo.trans_picking_ubic(fecha_verificado, ...)` with the verification-clean filter

## Current Diagnosis

- `despacho` is now driven by `trans_despacho_det.fec_agr` and can use the new dispatch-date index directly.
- `verificacion` still returns a large payload, but the date-filtered lookup path is now backed by the verification date index instead of scanning the full picking history.
- These fixes are additive; they do not replace the existing KPI indexes.

## Notes

- The WMS workspace anchor lives in `C:\Users\yejc2\OpenClawWorkspace\wms-brain\README.md`.
- The operational WMS repo is `C:\Users\yejc2\source\repos\TOMWMS`.
- Use the DB brain for SQL plans, indexes, and runtime tuning.
