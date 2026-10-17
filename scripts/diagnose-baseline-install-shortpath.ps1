#requires -Version 5.1
<#
  Samsung Q60A: teste de instalacao do WGT baseline ja assinado
  movendo APENAS o arquivo para caminho sem espacos.
  Nao recompila, nao assina, nao pede certificados/passwords.
  Assinatura interna do ZIP permanece inalterada.
  Nao testa nem liga VPN. Foi pensado para TV autorizada via SDB.
#>
[CmdletBinding()]
param([string]$TizenStudio = "C:\tizen-studio")
$ErrorActionPreference='Stop'
$cli=Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb=Join-Path $TizenStudio 'tools\sdb.exe'
if(!(Test-Path -LiteralPath $cli)){throw "Tizen CLI nao encontrada: $cli"}
if(!(Test-Path -LiteralPath $sdb)){throw "SDB nao encontrado: $sdb"}
Add-Type -AssemblyName System.IO.Compression.FileSystem
Write-Host '=== Teste baseline: pacote inalterado, nome/caminho sem espacos ==='
$files=@(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'HugoPartnerProbe_*' -ErrorAction SilentlyContinue |
  ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter '*.wgt' -ErrorAction SilentlyContinue } |
  Sort-Object LastWriteTime -Descending)
$source=$null
foreach($item in $files) {
  $zip=$null
  try {
    $zip=[IO.Compression.ZipFile]::OpenRead($item.FullName)
    $entries=@($zip.Entries | ForEach-Object{$_.FullName})
    if(@('config.xml','author-signature.xml','signature1.xml') | Where-Object {$entries -notcontains $_}){ continue }
    $entry=$zip.GetEntry('config.xml')
    $reader=New-Object System.IO.StreamReader($entry.Open())
    try{$config=$reader.ReadToEnd()}finally{$reader.Dispose()}
    if($config -match 'HugoTVB001\.BaselineProbe'){$source=$item;break}
  } catch {}
  finally {if($null -ne $zip){$zip.Dispose()}}
}
if($null -eq $source){throw 'Nao encontrei o WGT baseline assinado. Ainda nao instales nem recompiles; envia esta mensagem.'}

$folder=Join-Path $env:PUBLIC 'TizenProbeStage'
if($folder -match '\s'){throw "O caminho temporario ainda tem espacos: $folder"}
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$out=Join-Path $folder 'HugoBaselineProbe.wgt'
Copy-Item -LiteralPath $source.FullName -Destination $out -Force
$hashA=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
$hashB=(Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash
if($hashA -ne $hashB){throw 'A copia diverge do WGT assinado. Operacao cancelada.'}
Write-Host "WGT assinado copiado sem alteracoes para $out"
Write-Host 'SHA256 identico confirmado. Nenhum certificado foi manipulado.'

$devices=@(& $sdb devices 2>&1 | Where-Object{$_ -match '^\S+\s+device(?:\s|$)'})
if($devices.Count -ne 1){throw "Esperava exatamente uma TV ligada, encontrei $($devices.Count)."}
$serial=([regex]::Match($devices[0], '^\S+')).Value
Write-Host 'A instalar WGT por tizen CLI com nome e caminho sem espacos...'
& $cli install -s $serial -n 'HugoBaselineProbe.wgt' -- $folder
$exit=$LASTEXITCODE
if($exit -eq 0){
 Write-Host 'Instalacao concluida segundo a CLI. Confirma na TV a app Hugo Baseline Probe.'
 exit 0
}
Write-Host ''
Write-Host "CLI devolveu codigo $exit. A tentar obter erro detalhado atraves do instalador Samsung..."
Write-Host '(A mesma app e testada novamente; nao ha root nem modificacao de firmware.)'
$remote='/home/owner/share/tmp/sdk_tools/tmp/HugoBaselineProbe.wgt'
& $sdb shell 0 vd_appinstall 'HugoTVB001.BaselineProbe' $remote
Write-Host ''
Write-Host 'Envia as linhas finais do comando acima, especialmente install failed[CODIGO] ou motivo da rejeicao.'
Write-Host 'Se a shell nao permitir o diagnostico, diz-nos essa mensagem. Nao enviar certificados/chaves.'
