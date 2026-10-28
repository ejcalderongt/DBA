/*
  #EJC20260902_IMPLO_BOF_ATOMIC
  Infraestructura auditable para implosión manual BOF.
  Ejecutar primero en QA. El código BOF no permite aplicar si este contrato no existe.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM dbo.sis_tipo_tarea WHERE IdTipoTarea = 39 AND ISNULL(Nombre,'') <> N'IMPLO-BOF')
        THROW 51000, 'IdTipoTarea 39 ya está ocupado por otro contrato.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.sis_tipo_tarea WHERE IdTipoTarea = 39)
        INSERT dbo.sis_tipo_tarea (IdTipoTarea, Nombre, Contabilizar)
        VALUES (39, N'IMPLO-BOF', 1);

    IF OBJECT_ID(N'dbo.trans_implosion_enc', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.trans_implosion_enc
        (
            IdImplosionEnc            int IDENTITY(1,1) NOT NULL,
            TipoOperacion             varchar(20) NOT NULL,
            LicPlateDestino           nvarchar(50) NOT NULL,
            LicPlateGenerada          bit NOT NULL,
            IdEmpresa                 int NOT NULL,
            IdBodega                  int NOT NULL,
            IdPropietario             int NOT NULL,
            IdPropietarioBodega       int NOT NULL,
            IdProductoBodega          int NOT NULL,
            IdProductoTallaColor      int NULL,
            IdUnidadMedida            int NOT NULL,
            IdProductoEstado          int NOT NULL,
            IdUbicacion               int NOT NULL,
            Lote                      nvarchar(50) NOT NULL,
            FechaVence                datetime NULL,
            IdPresentacionDestino     int NULL,
            Factor                    float NOT NULL,
            CantidadProcesadaUmbas    float NOT NULL,
            PresentacionesGeneradas   int NOT NULL,
            RemanenteUmbas            float NOT NULL,
            IdOperadorBodega          int NOT NULL,
            UsuarioAgr                nvarchar(50) NOT NULL,
            HostAgr                   nvarchar(100) NULL,
            FechaAgr                  datetime NOT NULL CONSTRAINT DF_trans_implosion_enc_FechaAgr DEFAULT(GETDATE()),
            CONSTRAINT PK_trans_implosion_enc PRIMARY KEY CLUSTERED (IdImplosionEnc),
            CONSTRAINT CK_trans_implosion_enc_tipo CHECK (TipoOperacion IN ('CONVERSION','MOVIMIENTO_LP')),
            CONSTRAINT CK_trans_implosion_enc_factor CHECK ((TipoOperacion='CONVERSION' AND Factor > 0 AND IdPresentacionDestino IS NOT NULL AND PresentacionesGeneradas > 0) OR (TipoOperacion='MOVIMIENTO_LP' AND Factor=0 AND IdPresentacionDestino IS NULL AND PresentacionesGeneradas=0)),
            CONSTRAINT CK_trans_implosion_enc_cantidad CHECK (CantidadProcesadaUmbas > 0 AND RemanenteUmbas >= 0),
            CONSTRAINT FK_trans_implosion_enc_presentacion FOREIGN KEY (IdPresentacionDestino) REFERENCES dbo.producto_presentacion(IdPresentacion)
        );
    END;

    IF OBJECT_ID(N'dbo.trans_implosion_det', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.trans_implosion_det
        (
            IdImplosionDet          bigint IDENTITY(1,1) NOT NULL,
            IdImplosionEnc          int NOT NULL,
            IdMovimiento            int NOT NULL,
            IdStockOrigen           int NOT NULL,
            LicPlateOrigen          nvarchar(50) NULL,
            CantidadOrigenUmbas     float NOT NULL,
            IdStockDestino          int NOT NULL,
            LicPlateDestino         nvarchar(50) NOT NULL,
            CantidadAportadaUmbas   float NOT NULL,
            EsRemanente             bit NOT NULL,
            CONSTRAINT PK_trans_implosion_det PRIMARY KEY CLUSTERED (IdImplosionDet),
            CONSTRAINT FK_trans_implosion_det_enc FOREIGN KEY (IdImplosionEnc) REFERENCES dbo.trans_implosion_enc(IdImplosionEnc),
            CONSTRAINT CK_trans_implosion_det_cantidad CHECK (CantidadOrigenUmbas > 0 AND CantidadAportadaUmbas > 0)
        );

        CREATE INDEX IX_trans_implosion_det_origen ON dbo.trans_implosion_det(IdStockOrigen, IdImplosionEnc);
        CREATE INDEX IX_trans_implosion_det_destino ON dbo.trans_implosion_det(IdStockDestino, IdImplosionEnc);
        CREATE INDEX IX_trans_implosion_det_lp_destino ON dbo.trans_implosion_det(LicPlateDestino);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
