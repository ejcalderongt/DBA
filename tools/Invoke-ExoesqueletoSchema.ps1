param([Parameter(Mandatory=$true)][string]$BaseEsperada,
      [string]$ConexionIni,
      [string]$ServidorLocal,
      [switch]$Aplicar,
      [switch]$PrepararBasePrueba)
# #EJC20261027_EXO_ESQUEMA: despliegue explícito, destino verificado y sin secretos en salida.
$ErrorActionPreference='Stop'
$builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
if ($ServidorLocal) {
    if ($ServidorLocal -notin @('.\SQLEXPRESS','localhost\SQLEXPRESS')) {throw 'Solo SQL Express local para esta opción'}
    $builder['Data Source']=$ServidorLocal;$builder['Integrated Security']=$true
} else {
    if (-not $ConexionIni) {throw 'Falta ConexionIni o ServidorLocal'}
    $values=@{}
    Get-Content -LiteralPath $ConexionIni | ForEach-Object {if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') {$values[$matches[1].Trim()]=$matches[2].Trim()}}
    if ($values['NOMBRE_BD_WMS'] -ne $BaseEsperada) {throw 'La base del INI no coincide con BaseEsperada'}
    $builder['Data Source']=$values['SERVIDOR_BD_WMS'];$builder['User ID']=$values['USUARIO_BD_WMS'];$builder['Password']=$values['CLAVE_BD_WMS']
}
if ($BaseEsperada -match '(?i)killios') {throw 'KILLIOS es solo lectura desde este flujo'}
$builder['Connect Timeout']=10;$builder['Application Name']='WMS-Exoesqueleto-Schema'
if ($PrepararBasePrueba) {
    if (-not $ServidorLocal -or $BaseEsperada -ne 'WMS_EXO_TEST_20261027') {throw 'Preparación limitada a la base sintética local'}
    $builder['Initial Catalog']='master'
    $master=New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
    try {$master.Open();$cmd=$master.CreateCommand();$cmd.CommandText="IF DB_ID(N'WMS_EXO_TEST_20261027') IS NULL CREATE DATABASE [WMS_EXO_TEST_20261027]";[void]$cmd.ExecuteNonQuery()}finally{$master.Dispose()}
}
$builder['Initial Catalog']=$BaseEsperada
$cn=New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
try {
    $cn.Open();$cmd=$cn.CreateCommand();$cmd.CommandText='SELECT DB_NAME()'
    if ($cmd.ExecuteScalar() -ne $BaseEsperada) {throw 'Destino SQL no coincide'}
    if ($PrepararBasePrueba) {
        $cmd.CommandText="IF OBJECT_ID('dbo.bodega') IS NULL CREATE TABLE dbo.bodega(IdBodega int NOT NULL PRIMARY KEY); IF OBJECT_ID('dbo.bodega_ubicacion') IS NULL CREATE TABLE dbo.bodega_ubicacion(IdUbicacion int NOT NULL,IdBodega int NOT NULL,PRIMARY KEY(IdUbicacion,IdBodega));"
        [void]$cmd.ExecuteNonQuery()
    }
    $scriptPath=Join-Path (Split-Path $PSScriptRoot -Parent) '20261012_wms_exoesqueleto_versionado_proposal.sql'
    $script=Get-Content -LiteralPath $scriptPath -Raw
    if ($script -notmatch 'DECLARE @Aplicar bit = 0;') {throw 'Marcador de modo de ejecución no reconocido'}
    if ($Aplicar) {$script=$script.Replace('DECLARE @Aplicar bit = 0;','DECLARE @Aplicar bit = 1;')}
    $cmd.CommandTimeout=60;$cmd.CommandText=$script;[void]$cmd.ExecuteNonQuery()
    $tables=@()
    foreach ($table in @('bodega_ubicacion_exoesqueleto','bodega_ubicacion_exoesqueleto_nodo','bodega_ubicacion_exoesqueleto_enlace','bodega_ubicacion_exoesqueleto_acceso')) {
        $cmd.CommandText='SELECT OBJECT_ID(@name,''U'')';$cmd.Parameters.Clear();[void]$cmd.Parameters.AddWithValue('@name','dbo.'+$table)
        $exists=-not [Convert]::IsDBNull($cmd.ExecuteScalar())
        if ($Aplicar -and -not $exists) {throw "No se creó $table"}
        $tables+=[pscustomobject]@{tabla=$table;existe=$exists}
    }
    [pscustomobject]@{base=$BaseEsperada;modo=$(if($Aplicar){'APLICADO'}else{'DRY_RUN_REVERTIDO'});tablas=$tables;script_sha256=(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash} | ConvertTo-Json -Depth 5
} finally {$cn.Dispose()}
