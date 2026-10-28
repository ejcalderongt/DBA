-- #EJC20261028_MHS_UNIDAD_RECEPCION
-- Solo DEV. Una unidad usa SKU en QR y LP origen como texto. No cambia fardos/LP.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'TOMWMS_MHS_DEV' THROW 50001, 'Script restringido a TOMWMS_MHS_DEV.', 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @nombre nvarchar(100) = N'2.12 x 1.22 - MHS_UNIDAD';
    DECLARE @zpl nvarchar(max), @id int;
    SELECT @zpl=codigo_zpl FROM dbo.TIPO_ETIQUETA WHERE IdTipoEtiqueta=13 AND Nombre=N'2.12 x 1.22 - MHS_FARDO';
    IF @zpl IS NULL THROW 50002, 'No existe el diseño MHS_FARDO de referencia.', 1;
    SET @zpl=REPLACE(@zpl, N'^FDTOMWMS FARDO', N'^FDTOMWMS UNIDAD');
    SET @zpl=REPLACE(@zpl, N'^FD{0}', N'^FD{1}'); -- empresa
    SET @zpl=REPLACE(@zpl, N'^FD{2}', N'^FD{0}'); -- nombre producto
    SET @zpl=REPLACE(@zpl, N'^FDPRES:{7}', N'^FDUNIDAD');
    SET @zpl=REPLACE(@zpl, N'^FDCANT:{8}', N'^FDCANT:1');
    SET @zpl=REPLACE(@zpl, N'^FDLIC:{3}', N'^FDSKU:{2}');
    SET @zpl=REPLACE(@zpl, N'^FD{4}', N'^FDLP:{4}');
    IF @zpl LIKE N'%{7}%' OR @zpl LIKE N'%{8}%' OR @zpl LIKE N'%{9}%'
        THROW 50003, 'El diseño fuente cambió; revisar el contrato de unidad.', 1;
    SELECT @id=IdTipoEtiqueta FROM dbo.TIPO_ETIQUETA WITH (UPDLOCK,HOLDLOCK) WHERE Nombre=@nombre;
    IF @id IS NULL
    BEGIN
        SELECT @id=ISNULL(MAX(IdTipoEtiqueta),0)+1 FROM dbo.TIPO_ETIQUETA WITH (UPDLOCK,HOLDLOCK);
        INSERT dbo.TIPO_ETIQUETA (IdTipoEtiqueta,Nombre,Alto,Ancho,MargenIzq,MagenDer,MargenSup,MargenInf,
            user_agr,fec_agr,user_mod,fec_mod,activo,dpi,codigo_zpl,Idclasificacion_etiqueta,es_inkjet)
        SELECT @id,@nombre,Alto,Ancho,MargenIzq,MagenDer,MargenSup,MargenInf,
            'EJC',CONVERT(date,GETDATE()),'EJC',CONVERT(date,GETDATE()),1,dpi,@zpl,1,0
        FROM dbo.TIPO_ETIQUETA WHERE IdTipoEtiqueta=13;
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.TIPO_ETIQUETA WHERE IdTipoEtiqueta=@id AND codigo_zpl=@zpl AND Idclasificacion_etiqueta=1)
        THROW 50004, 'Ya existe un diseño de unidad diferente. No se sobrescribe.', 1;

    IF (SELECT COUNT(*) FROM dbo.PRODUCTO WITH (UPDLOCK,HOLDLOCK)
        WHERE (IdProducto=14 AND Codigo='PT169' AND IdTipoEtiqueta IN (12,@id))
           OR (IdProducto=30 AND Codigo='PT366' AND IdTipoEtiqueta IN (12,@id))
           OR (IdProducto=96 AND Codigo='PT744' AND IdTipoEtiqueta IN (11,@id))) <> 3
        THROW 50005, 'La configuración de productos cambió; revisar antes de aplicar.', 1;
    UPDATE dbo.PRODUCTO SET IdTipoEtiqueta=@id
    WHERE (IdProducto=14 AND Codigo='PT169' AND IdTipoEtiqueta=12)
       OR (IdProducto=30 AND Codigo='PT366' AND IdTipoEtiqueta=12)
       OR (IdProducto=96 AND Codigo='PT744' AND IdTipoEtiqueta=11);
    COMMIT;
    SELECT IdProducto,Codigo,IdTipoEtiqueta FROM dbo.PRODUCTO WHERE IdProducto IN (14,30,96);
    SELECT IdTipoEtiqueta,Nombre,Idclasificacion_etiqueta FROM dbo.TIPO_ETIQUETA WHERE IdTipoEtiqueta=@id;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
