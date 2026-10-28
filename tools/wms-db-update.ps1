[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [ValidateSet('Plan', 'Script', 'Apply')]
    [string]$Mode = 'Plan',

    [ValidateSet('Integrated', 'Sql')]
    [string]$Authentication = 'Integrated',

    [string]$User,

    [string]$PasswordEnvironmentVariable = 'WMS_DB_PASSWORD',

    [string]$OutputPath,

    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\migrations\manifest.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-SqlCmdArguments {
    <#
      Construye los argumentos comunes sin incorporar la clave. SQLCMDPASSWORD
      se mantiene en el entorno del proceso y nunca se escribe en consola.
    #>
    $arguments = @('-S', $Server, '-d', $Database, '-l', '15', '-b', '-X', '-r', '1')
    if ($Authentication -eq 'Integrated') {
        return $arguments + '-E'
    }
    if ([string]::IsNullOrWhiteSpace($User)) {
        throw 'User es requerido cuando Authentication=Sql.'
    }
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($PasswordEnvironmentVariable))) {
        throw "No existe la variable de entorno $PasswordEnvironmentVariable."
    }
    return $arguments + @('-U', $User)
}

function Invoke-WithSqlPassword {
    <#
      Expone la clave a sqlcmd solo durante una invocación y restaura el entorno
      anterior incluso cuando SQL Server devuelve un error.
    #>
    param([Parameter(Mandatory = $true)][scriptblock]$Action)
    if ($Authentication -ne 'Sql') {
        return & $Action
    }
    $previousPassword = [Environment]::GetEnvironmentVariable('SQLCMDPASSWORD')
    try {
        $env:SQLCMDPASSWORD = [Environment]::GetEnvironmentVariable($PasswordEnvironmentVariable)
        return & $Action
    }
    finally {
        if ($null -eq $previousPassword) {
            Remove-Item Env:\SQLCMDPASSWORD -ErrorAction SilentlyContinue
        }
        else {
            $env:SQLCMDPASSWORD = $previousPassword
        }
    }
}

function Invoke-WmsSqlQuery {
    <# Ejecuta una consulta corta y devuelve únicamente sus filas de texto. #>
    param([Parameter(Mandatory = $true)][string]$Query)
    $arguments = (Get-SqlCmdArguments) + @('-h', '-1', '-W', '-Q', $Query)
    $output = Invoke-WithSqlPassword -Action { & sqlcmd @arguments }
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd terminó con código $LASTEXITCODE."
    }
    return @($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Invoke-WmsSqlFile {
    <# Ejecuta un artefacto generado por el runner y detiene el flujo ante el primer error. #>
    param([Parameter(Mandatory = $true)][string]$Path)
    $arguments = (Get-SqlCmdArguments) + @('-i', $Path)
    Invoke-WithSqlPassword -Action { & sqlcmd @arguments }
    if ($LASTEXITCODE -ne 0) {
        throw "La migración falló con código $LASTEXITCODE."
    }
}

function Get-MigrationChecksum {
    <# El checksum vuelve inmutable una migración después de aplicada. #>
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-AppliedMigrations {
    <# Lee el ledger si existe; una base heredada sin ledger comienza con una lista vacía. #>
    $query = @"
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.wms_schema_migration', N'U') IS NOT NULL
    SELECT MigrationId + N'|' + Checksum FROM dbo.wms_schema_migration ORDER BY MigrationId;
"@
    $result = @{}
    foreach ($line in (Invoke-WmsSqlQuery -Query $query)) {
        $parts = $line.Trim() -split '\|', 2
        if ($parts.Count -eq 2) {
            $result[$parts[0]] = $parts[1].ToLowerInvariant()
        }
    }
    return $result
}

function Get-LedgerBootstrapSql {
    <# Crea una única fuente de verdad sobre qué migraciones recibió la base. #>
    return @"
IF OBJECT_ID(N'dbo.wms_schema_migration', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.wms_schema_migration
    (
        MigrationId       nvarchar(50)  NOT NULL,
        Descripcion       nvarchar(250) NOT NULL,
        Checksum          char(64)      NOT NULL,
        FechaAplicacion   datetime2(0)  NOT NULL
            CONSTRAINT DF_wms_schema_migration_FechaAplicacion DEFAULT SYSUTCDATETIME(),
        AplicadoPor       sysname       NOT NULL
            CONSTRAINT DF_wms_schema_migration_AplicadoPor DEFAULT ORIGINAL_LOGIN(),
        AplicadoDesde     nvarchar(128) NOT NULL
            CONSTRAINT DF_wms_schema_migration_AplicadoDesde DEFAULT HOST_NAME(),
        CONSTRAINT PK_wms_schema_migration PRIMARY KEY (MigrationId)
    );
END;
GO
"@
}

function New-MigrationBatch {
    <#
      Produce el mismo SQL para Script y Apply. Cada migración se ejecuta dentro
      de una transacción y solo registra el ledger después de completar su cambio.
    #>
    param(
        [Parameter(Mandatory = $true)]$Migration,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$Checksum
    )
    $id = [string]$Migration.id
    $description = ([string]$Migration.description).Replace("'", "''")
    $absoluteScript = [IO.Path]::GetFullPath($ScriptPath)
    return @"
PRINT N'Aplicando migración $id';
SET XACT_ABORT ON;
BEGIN TRANSACTION;
GO
:r "$absoluteScript"
GO
IF NOT EXISTS (SELECT 1 FROM dbo.wms_schema_migration WHERE MigrationId = N'$id')
BEGIN
    INSERT dbo.wms_schema_migration(MigrationId, Descripcion, Checksum)
    VALUES (N'$id', N'$description', '$Checksum');
END;
GO
COMMIT TRANSACTION;
GO
"@
}

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw 'sqlcmd no está instalado o no se encuentra en PATH.'
}

$manifestFile = [IO.Path]::GetFullPath($ManifestPath)
if (-not (Test-Path -LiteralPath $manifestFile)) {
    throw "No existe el manifiesto: $manifestFile"
}
$manifestRoot = Split-Path -Parent $manifestFile
$manifest = Get-Content -Raw -LiteralPath $manifestFile | ConvertFrom-Json
$applied = Get-AppliedMigrations
$pending = [Collections.Generic.List[object]]::new()

foreach ($migration in $manifest.migrations) {
    $scriptPath = [IO.Path]::GetFullPath((Join-Path $manifestRoot ([string]$migration.script)))
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "No existe el script de la migración $($migration.id): $scriptPath"
    }
    $checksum = Get-MigrationChecksum -Path $scriptPath
    if ($applied.ContainsKey([string]$migration.id)) {
        if ($applied[[string]$migration.id] -ne $checksum) {
            throw "La migración $($migration.id) cambió después de aplicada. No se continuará."
        }
        Write-Host "[OK]      $($migration.id) ya aplicada"
        continue
    }
    $pending.Add([pscustomobject]@{ Definition = $migration; Path = $scriptPath; Checksum = $checksum })
    Write-Host "[PENDIENTE] $($migration.id) $($migration.description)"
}

Write-Host "Base: $Database"
Write-Host "Aplicadas: $($applied.Count) | Pendientes: $($pending.Count)"
if ($Mode -eq 'Plan') {
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $safeDatabase = $Database -replace '[^a-zA-Z0-9_.-]', '_'
    $OutputPath = Join-Path (Get-Location) "wms-update-$safeDatabase.sql"
}
$outputFile = [IO.Path]::GetFullPath($OutputPath)
$content = [Text.StringBuilder]::new()
[void]$content.AppendLine('-- Generado por tools/wms-db-update.ps1. No contiene credenciales.')
[void]$content.AppendLine('SET NOCOUNT ON;')
[void]$content.AppendLine((Get-LedgerBootstrapSql))
foreach ($item in $pending) {
    [void]$content.AppendLine((New-MigrationBatch -Migration $item.Definition -ScriptPath $item.Path -Checksum $item.Checksum))
}
[IO.File]::WriteAllText($outputFile, $content.ToString(), [Text.UTF8Encoding]::new($true))
Write-Host "Script generado: $outputFile"

if ($Mode -eq 'Apply') {
    if ($pending.Count -eq 0) {
        Write-Host 'La base ya está actualizada; no se ejecutaron cambios.'
        exit 0
    }
    Invoke-WmsSqlFile -Path $outputFile
    Write-Host "Actualización completada: $($pending.Count) migración(es)."
}
