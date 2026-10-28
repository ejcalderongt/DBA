/* #EJC20260729_BODEGA_ASOCIACION_FLEXIBLE
   Habilita asociaciones uno-a-uno con IdUbicacion distinto por pareja de bodegas.
   Destino inicial: 10.0.0.31 / TOMWMS_MHS_DEV.
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.bodega_asociacion_virtual', N'U') IS NULL
BEGIN
    THROW 50001, 'No existe dbo.bodega_asociacion_virtual.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.bodega_asociacion_virtual
    GROUP BY IdBodegaOrigen, IdBodegaDestino, IdUbicacionOrigen
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50002, 'Existen ubicaciones origen asociadas más de una vez para la misma pareja de bodegas.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.bodega_asociacion_virtual
    GROUP BY IdBodegaOrigen, IdBodegaDestino, IdUbicacionDestino
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50003, 'Existen ubicaciones destino asociadas más de una vez para la misma pareja de bodegas.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.bodega_asociacion_virtual')
      AND name = N'CK_bodega_asociacion_virtual_ubicacion_igual'
)
    ALTER TABLE dbo.bodega_asociacion_virtual
        DROP CONSTRAINT CK_bodega_asociacion_virtual_ubicacion_igual;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.bodega_asociacion_virtual')
      AND name = N'UX_bodega_asociacion_virtual_origen'
)
    CREATE UNIQUE INDEX UX_bodega_asociacion_virtual_origen
        ON dbo.bodega_asociacion_virtual
           (IdBodegaOrigen, IdBodegaDestino, IdUbicacionOrigen);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.bodega_asociacion_virtual')
      AND name = N'UX_bodega_asociacion_virtual_destino'
)
    CREATE UNIQUE INDEX UX_bodega_asociacion_virtual_destino
        ON dbo.bodega_asociacion_virtual
           (IdBodegaOrigen, IdBodegaDestino, IdUbicacionDestino);

COMMIT TRANSACTION;

SELECT i.name, i.is_unique
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID(N'dbo.bodega_asociacion_virtual')
  AND i.name IN
      (N'UX_bodega_asociacion_virtual_origen',
       N'UX_bodega_asociacion_virtual_destino');
