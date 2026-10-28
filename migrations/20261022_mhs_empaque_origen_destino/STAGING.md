# MHS empaque — staging al perder VPN

#EJC20261022_MHS_EMPAQUE_STAGING

Estado actual: Erik solicitó retomar el ZPL. Conexión restablecida; pendiente-orientacion.sql aplicado y verificado en TOMWMS_MHS_DEV el 2026-10-22. No quedan cambios de BD de esta migración pendientes. Falta prueba física.

La plantilla coincidió exactamente con ultimo-zpl-confirmado.zpl antes de aplicar. Se guardó respaldo-al-retomar.zpl y verificacion-final.json confirma igualdad con propuesta.zpl, ausencia de ^PO y licencia 14 ANULADA/Activo=0. Se repitieron con éxito pruebas DAL contra DEV y pruebas offline. No se imprimió ni se reinició BOF desde el agente.

El resto de este documento conserva el plan histórico de recuperación.

Confirmado antes de perder conexión:
- Base TOMWMS_MHS_DEV; etiqueta 14 reemplazada por layout Origen/Destino.
- Licencia 14 / J6000000001 anulada (sin pedido 139 ni packing ni proyección de pallet encontrada); auditoría conservada.
- ultimo-zpl-confirmado.zpl refleja el ZPL leído y comparado con éxito en ese momento. Incluye ^POI; no se imprimió desde el agente.
- aplicado-inicial.sql es historial, no una migración pendiente para reejecutar.

Pendiente:
1. Consultar estado actual y comparar con ultimo-zpl-confirmado.zpl: no asumir que otro usuario no lo modificó.
2. pendiente-orientacion.sql retira ^POI (orientación global persistente) y mantiene los campos en orientación normal; valida coincidencia exacta y admite ya-aplicado sin reanular ni tocar la licencia.
3. Verificar contenido contra propuesta.zpl, comprobar que la licencia 14 siga anulada y fuera del listado operativo.
4. BOF nuevo debe estar cargado antes de imprimir plantilla con {7}, {8}, {9}. Reabrir aplicación tras guardar el trabajo del usuario.
5. Prueba física: orientación/legibilidad, nombres largos, usuario/fecha separados y QR con mismo payload $ + LicPlate.

aplicar.sql contiene el plan completo desde el ZPL original, pero no debe ejecutarse sobre esta BD: el primer paso y la anulación ya ocurrieron. Retomar con pendiente-orientacion.sql únicamente tras comparar.
revertir-plantilla.sql admite ambas variantes de orientación conocidas y restaura antes.zpl; nunca reactiva una licencia sin pedido.

No hay commit ni push. Scripts preparados en disco; no se añadieron cambios ajenos al índice Git.
