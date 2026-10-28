-- #EJC20261022_MHS_EMPAQUE_STAGING
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>N'TOMWMS_MHS_DEV' THROW 51000,'Base no autorizada',1;
-- HISTORICO aplicado antes de perder conexión. NO REEJECUTAR.
BEGIN TRAN;
UPDATE dbo.tipo_etiqueta SET codigo_zpl=N'^XA
^CI28
^POI
^MMT
^PW700
^LL0406
^LS0
^FO24,16^A0N,25,16^FH^FDEtiqueta de Empaque^FS
^FO535,20^A0N,20,11^FH^FB140,1,0,R,0^FD{6}^FS
^FO24,54^GB652,2,2^FS
^FO30,90^BQN,2,6^FDLA,{3}^FS
^FO230,74^A0N,34,18^FH^FDLic: {3}^FS
^FO230,118^A0N,20,11^FH^FDOrigen:^FS
^FO230,144^A0N,24,12^FH^FB440,2,2,L,0^FD{0}^FS
^FO230,204^A0N,20,11^FH^FDDestino:^FS
^FO230,230^A0N,24,12^FH^FB440,2,2,L,0^FD{7}^FS
^FO24,292^GB652,2,2^FS
^FO24,306^A0N,22,12^FH^FB652,1,0,L,0^FDDoc: {5}^FS
^FO24,340^A0N,20,10^FH^FB652,1,0,L,0^FDUsuario: {8}^FS
^FO24,372^A0N,20,10^FH^FDImpresion: {9}^FS
^PQ1,0,1,Y
^XZ' WHERE IdTipoEtiqueta=14 AND Nombre=N'EMPAQUE MHS' AND codigo_zpl COLLATE Latin1_General_100_BIN2=N'^XA
^MMT
^PW700
^LL0406
^LS0
^FT450,21^A0I,20,14^FH^FD{6}^FS
^FO2,40^GB670,5,5^FS
^FT270,61^A0I,30,24^FH^FD{5}^FS
^FT550,61^A0I,30,24^FH^FD{4}^FS
^FT360,61^A0I,30,24^FH^FDBodega:^FS
^FT670,367^A0I,25,24^FH^FDEtiqueta de Empaque^FS
^FO2,355^GB670,5,5^FS
^FO420,100
^BQI,2,12
^FDLA,{3}^FS
^FT350,300^A0I,50,40^FH^FDLic: {3}^FS
^FT350,240^A0I,50,40^FH^FDRuta: {2}^FS
^FT350,120^A0I,50,40^FH^FDERP: {0}^FS
^PQ1,0,1,Y
^XZ' COLLATE Latin1_General_100_BIN2;
IF @@ROWCOUNT<>1 BEGIN ROLLBACK; THROW 51001,'Plantilla cambió; revisar respaldo',1; END;
IF NOT EXISTS(SELECT 1 FROM dbo.trans_licencia_empaque le WITH(UPDLOCK,HOLDLOCK) WHERE le.IdLicenciaEmpaque=14 AND le.LicPlate=N'J6000000001' AND le.IdDocumento=139 AND le.TipoOrigen='PEDIDO' AND le.Estado='GENERADA' AND le.Activo=1 AND NOT EXISTS(SELECT 1 FROM dbo.trans_pe_enc pe WITH(HOLDLOCK) WHERE pe.IdPedidoEnc=le.IdDocumento) AND NOT EXISTS(SELECT 1 FROM dbo.trans_packing_enc pk WITH(HOLDLOCK) WHERE pk.no_linea=le.LicPlate) AND NOT EXISTS(SELECT 1 FROM dbo.i_nav_barras_pallet p WITH(HOLDLOCK) WHERE p.Codigo_Barra=le.LicPlate OR p.Codigo_Barra=N'$'+le.LicPlate)) BEGIN ROLLBACK; THROW 51002,'La licencia ya no cumple condiciones para anulación',1; END;
UPDATE dbo.trans_licencia_empaque SET Estado='ANULADA',Activo=0,FechaAnulacion=GETDATE(),MotivoAnulacion=N'EJC20261022: Licencia de pruebas sin pedido 139; sin packing. Retirada del flujo operativo.',user_mod=N'EJC',fec_mod=GETDATE() WHERE IdLicenciaEmpaque=14;
IF @@ROWCOUNT<>1 BEGIN ROLLBACK; THROW 51003,'No se anuló la licencia esperada',1; END;
COMMIT;