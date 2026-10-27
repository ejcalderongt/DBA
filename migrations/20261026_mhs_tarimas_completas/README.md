# #EJC20261026_MHS_TARIMA_COMPLETA

Migración aplicada a TOMWMS_MHS_DEV, servidor 10.0.0.31, el 2026-10-26.
Agrega EsRecicladaRecepcion con default 0 en trans_licencia_empaque.
Aplicar antes del DAL/Entity nuevo en cada base destino; no aplicado a producción.
No actualiza stock, reserva, picking, packing ni licencias históricas.
Rollback condicionado a que no existan licencias recicladas; revertir binarios primero.

validar-dev.ps1 requiere DLL Entity/DAL compiladas y credenciales del Conn.ini
local de BOF. No imprime ni guarda credenciales. Cada escenario revierte su
transacción. No imprimir etiquetas físicas con datos de estas pruebas.

Traza y resultados: TOMWMS_BOF/brain/handoffs/2026-10-26-mhs-tarimas-completas/.
Snapshot de prueba: pedido 126, picking 88, bodega 7/MH07, JM000141=1900,
JM000144=250, factor 25. Cambios futuros de esos datos exigen adaptar el fixture.

Limpieza #EJC20261027: los scripts validar-*.ps1 y resultados se trasladaron
al repositorio/branch wms-brain, brain/handoffs/2026-10-26-mhs-tarimas-completas/; no están en el repo fuente BOF.
