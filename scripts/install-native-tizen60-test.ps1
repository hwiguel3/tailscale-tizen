#requires -Version 5.1
<#
 Q60A native .TPK compatibility check. This TEST does NOT create a VPN.
 Requires artifact ZIP downloaded by user from:
 https://github.com/hwiguel3/tailscale-tizen/actions/runs/39041583763

 Usage:
   .\install-native-tizen60-test.ps1
   .\install-native-tizen60-test.ps1 -ZipPath "C:\Users\...\Downloads\native-tizen60-unverified-test-package.zip"

 The native .TPK created in GitHub is re-signed LOCALLY using the
 existing Samsung Partner certificate profile (never upload private keys).
 It is installed through the official Tizen CLI. There is no root/firmware
 modification. If the TV rejects .tpk, stop here and report the error.
#>
[CmdletBinding()]
param(
 [string]$ZipPath='',
 [string]$Profile='SamsungTV_Hugo_2',
 [string]$TizenStudio='C:\tizen-studio'
)
$ErrorActionPreference='Stop'
$cli=Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb=Join-Path $TizenStudio 'tools\sdb.exe'
if(!(Test-Path -LiteralPath $cli)){throw "Tizen CLI nao encontrada: $cli"}
if(!(Test-Path -LiteralPath $sdb)){throw "SDB nao encontrado: $sdb"}

if(!$ZipPath) {
  $downloads=Join-Path $env:USERPROFILE 'Downloads'
  $candidates=@(Get-ChildItem -LiteralPath $downloads -File -Filter 'native-tizen60-unverified-test-package*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if($candidates.Count -eq 0) {
    throw "Descarrega primeiro o artifact ZIP 'native-tizen60-unverified-test-package' do run 39041583763 no GitHub, para Downloads."
  }
  $ZipPath=$candidates[0].FullName
}
$ZipPath=(Resolve-Path -LiteralPath $ZipPath).Path
Write-Host "Artifact ZIP encontrado: $([IO.Path]::GetFileName($ZipPath))"

$stage=Join-Path $env:PUBLIC 'TizenProbeStage'
if($stage -match '\s'){throw "A pasta de staging contem espacos: $stage"}
New-Item -Path $stage -ItemType Directory -Force | Out-Null
$extractDir=Join-Path $stage 'NativeTizen60Extract'
if(Test-Path -LiteralPath $extractDir){Remove-Item -LiteralPath $extractDir -Recurse -Force}
New-Item -Path $extractDir -ItemType Directory | Out-Null
Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractDir
$packages=@(Get-ChildItem -LiteralPath $extractDir -File -Recurse -Filter '*.tpk')
if($packages.Count -ne 1){throw "Esperava exatamente 1 .tpk no artifact; encontrei $($packages.Count)."}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$pkg=$packages[0]
$zip=[IO.Compression.ZipFile]::OpenRead($pkg.FullName)
try {
  $manifest=$zip.GetEntry('tizen-manifest.xml')
  if(!$manifest){throw "O pacote nao contem tizen-manifest.xml."}
  $reader=New-Object IO.StreamReader($manifest.Open())
  try {$xmlText=$reader.ReadToEnd()}finally{$reader.Dispose()}
  if($xmlText -notmatch 'com\.hugo\.nativeprobe' -or $xmlText -notmatch 'HugoNativeProbe\.dll'){
    throw "Manifesto inesperado: nao parece ser o teste .NET da Q60A."
  }
}finally{$zip.Dispose()}
$targetName='HugoNativeProbe.tpk'
$target=Join-Path $stage $targetName
Copy-Item -LiteralPath $pkg.FullName -Destination $target -Force
Write-Host "Pacote minimo .NET Tizen 6 localizado, com manifesto verificado."
Write-Host "A re-assinar LOCALMENTE com certificado '$Profile' (sem upload de chaves)..."
& $cli package -t tpk -s $Profile -- $target
$signResult=$LASTEXITCODE
if($signResult -ne 0) {
  throw "Assinatura local falhou (codigo $signResult). Confirma o perfil $Profile na CLI. NAO instalar."
}
$zip=[IO.Compression.ZipFile]::OpenRead($target)
try {
 $names=@($zip.Entries | ForEach-Object {$_.FullName})
 $missing=@('tizen-manifest.xml','author-signature.xml','signature1.xml') | Where-Object {$names -notcontains $_}
 if($missing.Count -gt 0){throw "TPK nao contem assinaturas obrigatorias: $($missing -join ', ')"}
}finally{$zip.Dispose()}
Write-Host "Pacote re-assinado e verificado. A consultar TV SDB..."
$devices=@(& $sdb devices 2>&1 | Where-Object {$_ -match '^\S+\s+device(?:\s|$)'})
if($devices.Count -ne 1){throw "Esperava exatamente 1 Samsung TV ligada por SDB; encontrei $($devices.Count)."}
$serial=([regex]::Match($devices[0], '^\S+')).Value
Write-Host "A tentar instalar SOMENTE o teste .NET minimo; nao modifica VPN/rotas/firmware."
& $cli install -s $serial -n $targetName -- $stage
$installCode=$LASTEXITCODE
if($installCode -eq 0){
 Write-Host "TPK INSTALADO. Abre 'Hugo Native Probe' na TV (se aparecer) e fotografa."
 Write-Host "Instalacao .NET nao demonstra acesso VPN global."
}else{
 Write-Host "TV REJEITOU o TPK (codigo CLI $installCode). O teste foi concluido sem alterar firmware."
 Write-Host "Envia o erro da instalacao; nao tentes root/flash nem repitas o TPK em loop."
}
