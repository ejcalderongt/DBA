# Migraciones versionadas de TOMWMS

Este directorio convierte los cambios de esquema en una secuencia reproducible.
Su objetivo es que una base restaurada pueda declarar qué cambios recibió y
alcanzar el contrato esperado por la versión actual del WMS sin descubrir
columnas faltantes durante el inicio de sesión.

## Flujo seguro

1. `Plan` compara el manifiesto con `dbo.wms_schema_migration` y no modifica la base.
2. `Script` genera el SQL consolidado pendiente, listo para revisión o entrega a DBA.
3. `Apply` genera ese mismo SQL y lo ejecuta con `XACT_ABORT` y una transacción por migración.
4. El checksum impide modificar silenciosamente un script que ya fue aplicado.

```powershell
# Diagnóstico sin cambios
.\tools\wms-db-update.ps1 `
  -Server '.\PROGRAX' `
  -Database 'MI_BASE_RESTAURADA' `
  -Mode Plan

# Generar el paquete SQL pendiente
.\tools\wms-db-update.ps1 `
  -Server '.\PROGRAX' `
  -Database 'MI_BASE_RESTAURADA' `
  -Mode Script `
  -OutputPath '.\artifacts\MI_BASE_RESTAURADA-update.sql'

# Aplicarlo localmente
.\tools\wms-db-update.ps1 `
  -Server '.\PROGRAX' `
  -Database 'MI_BASE_RESTAURADA' `
  -Mode Apply
```

Para autenticación SQL no se acepta la clave como argumento. Se guarda en una
variable de entorno de la sesión y se indica únicamente su nombre:

```powershell
$env:WMS_DB_PASSWORD = Read-Host 'Clave SQL' -MaskInput
.\tools\wms-db-update.ps1 -Server '.\PROGRAX' -Database 'MI_BASE' `
  -Authentication Sql -User 'usuario' -PasswordEnvironmentVariable WMS_DB_PASSWORD
```

## Regla para nuevas migraciones

- Un archivo nuevo; nunca reescribir uno aplicado.
- Nombre `VyyyyMMdd_NNN__descripcion.sql`.
- Seguro al reintentar: comprobar existencia antes de crear o alterar.
- Fallar explícitamente cuando falta una precondición estructural.
- Agregarlo al final de `manifest.json`.
- No incluir datos particulares de clientes ni credenciales.

Los archivos históricos de la raíz del repo siguen siendo referencias de
objetos y entregables. Solo los scripts incluidos en este manifiesto forman
parte del actualizador automático.
