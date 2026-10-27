# Persistencia del exoesqueleto y compatibilidad de picking

<!-- #EJC20261027_EXO_DBA -->

Repositorio canónico: https://github.com/ejcalderongt/DBA.
Paquete exclusivamente SQL y herramienta de despliegue; el graficador y Entity/DAL
pertenecen a BOF. El brain conserva la interpretación y las evidencias de prueba.

## Archivos y alcance

- `20261012_wms_exoesqueleto_versionado_proposal.sql`: cabecera versionada,
  nodos, enlaces y relación entre ubicación de bodega y nodo de acceso. Usa llaves
  compuestas, restricciones e índices. Requiere las tablas WMS `bodega` y
  `bodega_ubicacion` y sus claves referenciadas. No aprueba versiones ni migra stock.
- `tools/Invoke-ExoesqueletoSchema.ps1`: verifica el destino esperado, ejecuta
  el modo transaccional y comprueba existencia de las cuatro tablas. Recibe
  credenciales desde el INI local y no las imprime. Bloquea KILLIOS.
- `20261027_caremed_requiere_ubicacion_destino_picking.sql`: reparación acotada
  a CAREMED de `trans_pe_tipo.requiere_ubicacion_destino_picking`, `bit NOT NULL
  DEFAULT (0)`. Conserva la opción desactivada. Es compatible con el cambio más
  amplio ya versionado en `picking_ubicacion_destino_y_despacho_directo`; no ejecuta
  las demás modificaciones de ese cambio.

## Ejecución explícita

El SQL inicia con `@Aplicar = 0`: valida dentro de una transacción y revierte.
Para la persistencia, desde la raíz de DBA:

```powershell
tools/Invoke-ExoesqueletoSchema.ps1 -BaseEsperada <base> -ConexionIni <ruta-INI>
tools/Invoke-ExoesqueletoSchema.ps1 -BaseEsperada <base> -ConexionIni <ruta-INI> -Aplicar
```

La segunda orden aplica. Para el arreglo específico de CAREMED, revisar el
destino verificado por el SQL y cambiar `@Aplicar` a `1` al ejecutarlo. Publicar
los archivos no ejecuta scripts sobre otras bases.

## Evidencia del 27 de octubre de 2026

- Esquema probado con rollback y aplicación en SQL Express local.
- DAL probado localmente: guardar, cargar coordenadas, actualizar borrador y
  retirar el borrador sintético. Detección de esquema faltante comprobada.
- Las cuatro tablas se aplicaron en `TOMWMS_CAREMED_PRD` por solicitud explícita
  del usuario, después del dry run. No se modificaron datos de negocio.
- La columna específica se validó contra MHS DEV y se aplicó en CAREMED con
  prueba de idempotencia: nueve tipos de pedido conservaron el valor `0`.

## Siguiente contrato funcional

La tabla `bodega_ubicacion_exoesqueleto_acceso` define la unión pendiente entre
`(IdBodega, IdUbicacion)` y `(IdVersion, IdNodoAcceso)`. La recuperación inicial
del graficador persistía cabecera/nodos/enlaces; todavía debe implementarse y
validarse Entity/DAL de accesos y la selección de una versión aprobada.

Con esa unión, un picking puede consultar sus ubicaciones asignadas y simular
el recorrido desde inicio a accesos y entrega. No implica cambiar reservas,
FEFO, cantidades o estados del picking. La zona de piso de CAREMED, tramo 19,
requiere delimitación y acceso físico antes de certificar su cobertura.
