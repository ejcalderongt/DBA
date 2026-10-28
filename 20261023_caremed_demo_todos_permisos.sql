-- #EJC20261023 Permisos completos BOF/HH exclusivamente demo CAREMED local.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> 'TOMWMS_CAREMED_PRD' OR CONVERT(nvarchar(128),SERVERPROPERTY('MachineName')) <> 'prograx' THROW 50000,'Destino no autorizado',1;
BEGIN TRAN;
UPDATE m SET activo=1,visible=1,leer=1,modificar=1,eliminar=1,user_mod='EJC_DEMO',fec_mod=GETDATE()
FROM dbo.menu_rol m JOIN dbo.rol r ON r.IdRol=m.IdRol WHERE r.IdEmpresa=1;
DECLARE @max int=(SELECT ISNULL(MAX(IdMenuRol),0) FROM dbo.menu_rol WITH(UPDLOCK,HOLDLOCK));
INSERT dbo.menu_rol(IdMenuRol,IdMenu,IdRol,user_agr,fec_agr,user_mod,fec_mod,activo,visible,leer,modificar,eliminar)
SELECT @max+ROW_NUMBER() OVER(ORDER BY r.IdRol,s.IdMenu),s.IdMenu,r.IdRol,'EJC_DEMO',GETDATE(),'EJC_DEMO',GETDATE(),1,1,1,1,1
FROM dbo.rol r CROSS JOIN dbo.menu_sistema s WHERE r.IdEmpresa=1
AND NOT EXISTS(SELECT 1 FROM dbo.menu_rol m WHERE m.IdRol=r.IdRol AND m.IdMenu=s.IdMenu);
UPDATE m SET activo=1,visible=1,user_mod='EJC_DEMO',fec_mod=GETDATE()
FROM dbo.menu_rol_op m JOIN dbo.rol_operador r ON r.IdRolOperador=m.IdRolOperador;
INSERT dbo.menu_rol_op(IdMenuSistemaOP,IdRolOperador,user_agr,fec_agr,user_mod,fec_mod,visible,activo)
SELECT s.IdMenuSistemaOP,r.IdRolOperador,'EJC_DEMO',GETDATE(),'EJC_DEMO',GETDATE(),1,1
FROM dbo.rol_operador r CROSS JOIN dbo.menu_sistema_op s
WHERE NOT EXISTS(SELECT 1 FROM dbo.menu_rol_op m WHERE m.IdRolOperador=r.IdRolOperador AND m.IdMenuSistemaOP=s.IdMenuSistemaOP);
IF EXISTS(SELECT 1 FROM dbo.rol r CROSS JOIN dbo.menu_sistema s WHERE r.IdEmpresa=1 AND NOT EXISTS(SELECT 1 FROM dbo.menu_rol m WHERE m.IdRol=r.IdRol AND m.IdMenu=s.IdMenu AND m.activo=1 AND m.visible=1 AND m.leer=1 AND m.modificar=1 AND m.eliminar=1)) THROW 50001,'Faltan permisos BOF',1;
IF EXISTS(SELECT 1 FROM dbo.rol_operador r CROSS JOIN dbo.menu_sistema_op s WHERE NOT EXISTS(SELECT 1 FROM dbo.menu_rol_op m WHERE m.IdRolOperador=r.IdRolOperador AND m.IdMenuSistemaOP=s.IdMenuSistemaOP AND m.visible=1 AND m.activo=1)) THROW 50002,'Faltan permisos HH',1;
COMMIT;
SELECT r.IdRol,r.nombre,COUNT(*) AS MenusHabilitados FROM dbo.rol r JOIN dbo.menu_rol m ON m.IdRol=r.IdRol WHERE r.IdEmpresa=1 AND m.activo=1 AND m.visible=1 AND m.leer=1 AND m.modificar=1 AND m.eliminar=1 GROUP BY r.IdRol,r.nombre;
SELECT r.IdRolOperador,r.Nombre,COUNT(*) AS MenusHabilitados FROM dbo.rol_operador r JOIN dbo.menu_rol_op m ON m.IdRolOperador=r.IdRolOperador WHERE m.activo=1 AND m.visible=1 GROUP BY r.IdRolOperador,r.Nombre;
