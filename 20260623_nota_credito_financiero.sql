SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  EJC20260623_NC_FINANCIERO
  Propuesta unica para aprobacion.

  Objetivo:
    - Crear la base estructural de Nota de Credito.
    - Soportar dos orígenes de factura en la misma pantalla:
      * DTS / ERP: D_FACTURA + D_FACTURAD
      * mPos / POS: D_VENTA_BOF + D_VENTAD_BOF
    - Insertar la opcion de menu en el modulo Financiero.
    - Habilitar la opcion para los roles que hoy usan:
      * admindts  -> RoleId 1
      * adminimno -> RoleId 15

  Nota:
    - La NC fiscal debe seguir la referencia del documento origen.
    - Este script no ejecuta ningun flujo de negocio; solo deja estructura y permisos.
    - Dejar @DryRun = 1 para revisar y rollback. Cambiar a 0 solo cuando se apruebe.
*/

DECLARE @DryRun bit = 1;
DECLARE @ModuloFinanciero int = 10;
DECLARE @MenuEnlace nvarchar(200) = N'venta/nota_credito';
DECLARE @MenuNombre nvarchar(200) = N'Notas de crédito';
DECLARE @MenuIcono nvarchar(100) = N'ri-refund-2-line';
DECLARE @MenuId int = NULL;

DECLARE @RolesObjetivo TABLE (
    role_id int NOT NULL PRIMARY KEY
);

INSERT INTO @RolesObjetivo (role_id)
VALUES (1), (15);

BEGIN TRY
    BEGIN TRAN;

    /* ============================================================
       1) Estructura NC
       ============================================================ */

    IF OBJECT_ID('dbo.d_nota_credito_bof_estatus', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.d_nota_credito_bof_estatus (
            codigo_nota_credito_estatus int NOT NULL,
            nombre nvarchar(50) NOT NULL,
            permite_editar bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_estatus_permite_editar DEFAULT (0),
            aplica_inventario bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_estatus_aplica_inventario DEFAULT (0),
            certificada bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_estatus_certificada DEFAULT (0),
            anulada bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_estatus_anulada DEFAULT (0),
            CONSTRAINT PK_d_nota_credito_bof_estatus
                PRIMARY KEY CLUSTERED (codigo_nota_credito_estatus)
        );

        INSERT INTO dbo.d_nota_credito_bof_estatus
            (codigo_nota_credito_estatus, nombre, permite_editar, aplica_inventario, certificada, anulada)
        VALUES
            (1, N'Borrador', 1, 0, 0, 0),
            (2, N'Certificada', 0, 1, 1, 0),
            (3, N'Error FEL', 1, 0, 0, 0),
            (4, N'Anulada', 0, 0, 0, 1);
    END;

    IF OBJECT_ID('dbo.d_nota_credito_bof_enc', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.d_nota_credito_bof_enc (
            codigo_nota_credito int IDENTITY(1,1) NOT NULL,
            empresa int NOT NULL,
            codigo_sucursal int NULL,
            codigo_ruta int NULL,
            origen_sistema nvarchar(10) NOT NULL,
            origen_tabla nvarchar(30) NOT NULL,
            codigo_documento_origen nvarchar(50) NOT NULL,
            codigo_documento_det_origen nvarchar(50) NULL,
            codigo_cliente int NULL,
            codigo_cliente_contacto int NULL,
            codigo_media_pago int NULL,
            codigo_moneda int NULL,
            codigo_vendedor int NULL,
            codigo_nota_credito_estatus int NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_estatus DEFAULT (1),
            fecha date NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_fecha DEFAULT (CONVERT(date, GETDATE())),
            fecha_agr datetime NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_fecha_agr DEFAULT (GETDATE()),
            fecha_mod datetime NULL,
            usuario_agr int NOT NULL,
            usuario_mod int NULL,
            activo bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_activo DEFAULT (1),
            anulado bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_anulado DEFAULT (0),
            anulado_fecha datetime NULL,
            usuario_anula int NULL,
            anulado_razon nvarchar(500) NULL,
            motivo nvarchar(500) NOT NULL,
            referencia nvarchar(150) NULL,
            observaciones nvarchar(1000) NULL,
            maneja_talla_color bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_maneja_tc DEFAULT (0),
            usa_firebase bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_usa_fb DEFAULT (0),
            inventario_aplicado bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_inv_aplicado DEFAULT (0),
            fecha_aplica_inventario datetime NULL,
            corel_d_mov nvarchar(20) NULL,
            corel_d_mov_almacen nvarchar(20) NULL,
            fel_tipo_dte nvarchar(10) NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_tipo_dte DEFAULT (N'NCRE'),
            fel_uuid_ref nvarchar(100) NOT NULL,
            fel_serie_ref nvarchar(100) NULL,
            fel_numero_ref nvarchar(100) NULL,
            fecha_certificacion_ref datetime NULL,
            fel_uuid nvarchar(100) NULL,
            fel_serie nvarchar(100) NULL,
            fel_numero nvarchar(100) NULL,
            fecha_certificacion datetime NULL,
            total float NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_total DEFAULT (0),
            descuento float NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_descuento DEFAULT (0),
            impuesto_total decimal(18, 6) NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_impuesto DEFAULT (0),
            importe_exento decimal(18, 6) NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_exento DEFAULT (0),
            importe_gravado decimal(18, 6) NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_gravado DEFAULT (0),
            importe_exonerado decimal(18, 6) NOT NULL CONSTRAINT DF_d_nota_credito_bof_enc_exonerado DEFAULT (0),
            CONSTRAINT PK_d_nota_credito_bof_enc
                PRIMARY KEY CLUSTERED (codigo_nota_credito),
            CONSTRAINT FK_d_nota_credito_bof_enc_estatus
                FOREIGN KEY (codigo_nota_credito_estatus)
                REFERENCES dbo.d_nota_credito_bof_estatus (codigo_nota_credito_estatus),
            CONSTRAINT CK_d_nota_credito_bof_enc_origen
                CHECK (origen_sistema IN (N'DTS', N'MPOS'))
        );
    END;

    IF OBJECT_ID('dbo.d_nota_credito_bof_det', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.d_nota_credito_bof_det (
            codigo_nota_credito_det int IDENTITY(1,1) NOT NULL,
            codigo_nota_credito int NOT NULL,
            origen_detalle_tabla nvarchar(30) NULL,
            codigo_documento_det_origen nvarchar(50) NULL,
            codigo_producto int NOT NULL,
            cantidad float NOT NULL,
            precio_venta float NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_precio DEFAULT (0),
            descuento float NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_descuento DEFAULT (0),
            descuento_porcentaje decimal(18, 6) NULL,
            impuesto_total decimal(18, 6) NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_impuesto DEFAULT (0),
            total float NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_total DEFAULT (0),
            nombre_producto nvarchar(1000) NULL,
            texto_adicional nvarchar(500) NULL,
            tipo_producto_fel nvarchar(2) NULL,
            es_serializado bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_serial DEFAULT (0),
            unidadmedida nvarchar(10) NOT NULL,
            talla nvarchar(50) NULL,
            color nvarchar(50) NULL,
            unidadmedida_variante nvarchar(100) NULL,
            key_firebase varchar(30) NULL,
            cant_anterior float NULL,
            cant_nueva float NULL,
            motivo_ajuste int NULL,
            coreldet_d_mov int NULL,
            coreldet_d_mov_almacen int NULL,
            anulado bit NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_anulado DEFAULT (0),
            fecha_agr datetime NOT NULL CONSTRAINT DF_d_nota_credito_bof_det_fecha_agr DEFAULT (GETDATE()),
            fecha_mod datetime NULL,
            usuario_agr int NOT NULL,
            usuario_mod int NULL,
            CONSTRAINT PK_d_nota_credito_bof_det
                PRIMARY KEY CLUSTERED (codigo_nota_credito_det),
            CONSTRAINT FK_d_nota_credito_bof_det_enc
                FOREIGN KEY (codigo_nota_credito)
                REFERENCES dbo.d_nota_credito_bof_enc (codigo_nota_credito)
        );
    END;

    IF OBJECT_ID('dbo.d_nota_credito_bof_serie', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.d_nota_credito_bof_serie (
            codigo_nota_credito_serie int IDENTITY(1,1) NOT NULL,
            codigo_nota_credito_det int NOT NULL,
            codigo_documento_serie_origen nvarchar(50) NULL,
            serie nvarchar(50) NOT NULL,
            fecha_agr datetime NOT NULL CONSTRAINT DF_d_nota_credito_bof_serie_fecha_agr DEFAULT (GETDATE()),
            usuario_agr int NOT NULL,
            CONSTRAINT PK_d_nota_credito_bof_serie
                PRIMARY KEY CLUSTERED (codigo_nota_credito_serie),
            CONSTRAINT FK_d_nota_credito_bof_serie_det
                FOREIGN KEY (codigo_nota_credito_det)
                REFERENCES dbo.d_nota_credito_bof_det (codigo_nota_credito_det)
        );
    END;

    IF OBJECT_ID('dbo.d_nota_credito_bof_fel_log_error', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.d_nota_credito_bof_fel_log_error (
            codigo_nota_credito_fel_log_error int IDENTITY(1,1) NOT NULL,
            codigo_nota_credito int NOT NULL,
            mensaje nvarchar(max) NULL,
            xml nvarchar(max) NULL,
            respuesta nvarchar(max) NULL,
            fecha_agr datetime NOT NULL CONSTRAINT DF_d_nota_credito_bof_fel_log_fecha DEFAULT (GETDATE()),
            usuario_agr int NOT NULL,
            CONSTRAINT PK_d_nota_credito_bof_fel_log_error
                PRIMARY KEY CLUSTERED (codigo_nota_credito_fel_log_error),
            CONSTRAINT FK_d_nota_credito_bof_fel_log_error_enc
                FOREIGN KEY (codigo_nota_credito)
                REFERENCES dbo.d_nota_credito_bof_enc (codigo_nota_credito)
        );
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_d_nota_credito_bof_enc_empresa_fecha'
          AND object_id = OBJECT_ID('dbo.d_nota_credito_bof_enc')
    )
    BEGIN
        CREATE INDEX IX_d_nota_credito_bof_enc_empresa_fecha
            ON dbo.d_nota_credito_bof_enc (empresa, fecha DESC, codigo_sucursal)
            INCLUDE (codigo_nota_credito_estatus, codigo_documento_origen, total, fel_uuid, fel_numero);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_d_nota_credito_bof_enc_origen'
          AND object_id = OBJECT_ID('dbo.d_nota_credito_bof_enc')
    )
    BEGIN
        CREATE INDEX IX_d_nota_credito_bof_enc_origen
            ON dbo.d_nota_credito_bof_enc (origen_sistema, origen_tabla, codigo_documento_origen)
            INCLUDE (empresa, fecha, codigo_sucursal, codigo_nota_credito_estatus, total, fel_uuid);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_d_nota_credito_bof_det_enc'
          AND object_id = OBJECT_ID('dbo.d_nota_credito_bof_det')
    )
    BEGIN
        CREATE INDEX IX_d_nota_credito_bof_det_enc
            ON dbo.d_nota_credito_bof_det (codigo_nota_credito, anulado)
            INCLUDE (codigo_producto, cantidad, total, unidadmedida, unidadmedida_variante, origen_detalle_tabla);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_d_nota_credito_bof_det_origen'
          AND object_id = OBJECT_ID('dbo.d_nota_credito_bof_det')
    )
    BEGIN
        CREATE INDEX IX_d_nota_credito_bof_det_origen
            ON dbo.d_nota_credito_bof_det (codigo_documento_det_origen, anulado);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'UX_d_nota_credito_bof_serie_det_serie'
          AND object_id = OBJECT_ID('dbo.d_nota_credito_bof_serie')
    )
    BEGIN
        CREATE UNIQUE INDEX UX_d_nota_credito_bof_serie_det_serie
            ON dbo.d_nota_credito_bof_serie (codigo_nota_credito_det, serie);
    END;

    /* ============================================================
       2) Menu Financiero / permisos por rol
       ============================================================ */

    SELECT TOP 1
        @MenuId = id
    FROM dbo.p_menuopcion
    WHERE enlace = @MenuEnlace
    ORDER BY id DESC;

    IF @MenuId IS NULL
    BEGIN
        INSERT INTO dbo.p_menuopcion (
            nombre,
            enlace,
            icono,
            padre,
            activo,
            modulo_id,
            nuevo
        ) VALUES (
            @MenuNombre,
            @MenuEnlace,
            @MenuIcono,
            0,
            1,
            @ModuloFinanciero,
            1
        );

        SET @MenuId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.p_menuopcion
        SET
            nombre = @MenuNombre,
            icono = @MenuIcono,
            padre = 0,
            activo = 1,
            modulo_id = @ModuloFinanciero,
            nuevo = 1
        WHERE id = @MenuId;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.p_modulos
        WHERE idmodulo = @ModuloFinanciero
    )
    BEGIN
        THROW 50000, 'No se encontro el modulo Financiero (10) en p_modulos.', 1;
    END;

    /* Activar o crear el enlace modulo-rol para los dos roles objetivo */
    UPDATE mr
    SET activo = 1
    FROM dbo.p_modulos_rol mr
    INNER JOIN @RolesObjetivo r
        ON r.role_id = mr.rol_id
    WHERE mr.modulo_id = @ModuloFinanciero;

    INSERT INTO dbo.p_modulos_rol (modulo_id, rol_id, activo)
    SELECT @ModuloFinanciero, r.role_id, 1
    FROM @RolesObjetivo r
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.p_modulos_rol mr
        WHERE mr.modulo_id = @ModuloFinanciero
          AND mr.rol_id = r.role_id
    );

    DECLARE @ModuloRoles TABLE (
        modulo_rol_id int NOT NULL PRIMARY KEY,
        rol_id int NOT NULL
    );

    INSERT INTO @ModuloRoles (modulo_rol_id, rol_id)
    SELECT
        mr.id,
        mr.rol_id
    FROM dbo.p_modulos_rol mr
    INNER JOIN @RolesObjetivo r
        ON r.role_id = mr.rol_id
    WHERE mr.modulo_id = @ModuloFinanciero
      AND mr.activo = 1;

    UPDATE pr
    SET activo = 1
    FROM dbo.p_menuopcion_rol pr
    INNER JOIN @ModuloRoles mr
        ON mr.modulo_rol_id = pr.modulo_rol_id
    WHERE pr.menuopcion_id = @MenuId;

    INSERT INTO dbo.p_menuopcion_rol (menuopcion_id, modulo_rol_id, activo)
    SELECT
        @MenuId,
        mr.modulo_rol_id,
        1
    FROM @ModuloRoles mr
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.p_menuopcion_rol pr
        WHERE pr.menuopcion_id = @MenuId
          AND pr.modulo_rol_id = mr.modulo_rol_id
    );

    /* ============================================================
       3) Salida de validacion
       ============================================================ */

    SELECT
        @MenuId AS menu_id,
        @MenuNombre AS menu_nombre,
        @MenuEnlace AS menu_enlace,
        @ModuloFinanciero AS modulo_id,
        (SELECT COUNT(1) FROM dbo.p_menuopcion_rol WHERE menuopcion_id = @MenuId) AS total_permisos_menu,
        (SELECT COUNT(1) FROM dbo.d_nota_credito_bof_enc) AS nc_cabeceras_actuales,
        (SELECT COUNT(1) FROM dbo.d_nota_credito_bof_det) AS nc_detalles_actuales;

    IF @DryRun = 1
    BEGIN
        ROLLBACK TRAN;
        PRINT 'Dry-run completado. No se guardaron cambios.';
    END
    ELSE
    BEGIN
        COMMIT TRAN;
        PRINT 'Cambios aplicados y confirmados.';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    DECLARE @Msg nvarchar(4000) = ERROR_MESSAGE();
    DECLARE @Sev int = ERROR_SEVERITY();
    DECLARE @Sta int = ERROR_STATE();

    RAISERROR(@Msg, @Sev, @Sta);
END CATCH;
