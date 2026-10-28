# #EJC20261026_PICKING_VISOR_EMPAQUE

No es una migración de esquema: solo consulta parametrizada y validación.
consulta-visor.sql coincide con el batch de Get_Visor_Empaque_Picking en DAL.
Parámetros: @Picking int, @Bodega int. Retorna Licencias, Contenido y Proceso.
Requiere el esquema de trans_licencia_empaque ya instalado (incluye la marca
EsRecicladaRecepcion del cambio previo). No agrega campos, índices ni escrituras.

validar-visor-dev.ps1 prueba la DLL compilada en MHS-DEV con fixtures transaccionales;
revierte todo el packing de prueba y los cambios a cabeceras. Lee credenciales del
Conn.ini local sin imprimirlas. Datos de fixture 126/88/MH07; revisar si el caso cambia.
Resultados y contrato de reportes: TOMWMS_BOF/brain/handoffs/2026-10-26-picking-visor-empaque/.

Limpieza #EJC20261027: los scripts validar-*.ps1 y resultados se trasladaron
al repositorio/branch wms-brain, brain/handoffs/2026-10-26-picking-visor-empaque/; no están en el repo fuente BOF.
