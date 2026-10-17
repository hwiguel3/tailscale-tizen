#requires -Version 5.1
<#
  Samsung Q60A: tentar instalar o ultimo WGT Partner previamente assinado.
  - NAO volta a descarregar o repo nem a compilar
  - NAO le certificados nem pede passwords
  - valida os ficheiros de assinatura no WGT e reutiliza-o
  - pede a autorizacao de instalacao em Developer Mode pelo Tizen CLI
  - captura a saida da ferramenta para investigar falhas
#>
[CmdletBinding()]
param([string]$TizenStudio = 'C:\tizen-studio')
$ErrorActionPreference='Stop'
$cli=Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb=Join-Path $TizenStudio 'tools\sdb.exe'
if(!(Test-Path -LiteralPath $cli)){throw "Tizen CLI nao encontrada em $cli"}
if(!(Test-Path -LiteralPath $sdb)){throw "SDB nao encontrado em $sdb"}
Add-Type -AssemblyName System.IO.Compression.FileSystem

$all = @(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'HugoPartnerProbe_*' -ErrorAction SilentlyContinue |
  ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*.wgt' -File -Recurse -ErrorAction SilentlyContinue } |
  Sort-Object LastWriteTime -Descending)
$valid=$null
foreach($file in $all){
  $zip=$null
  try{
    $zip=[IO.Compression.ZipFile]::OpenRead($file.FullName)
    $entries=@($zip.Entries | ForEach-Object {$_.FullName})
    $ok = @('config.xml','author-signature.xml','signature1.xml') |
      Where-Object {$entries -notcontains $_}
    if($ok.Count -eq 0){$valid=$file;break}
  }catch{}
  finally{if($null -ne $zip){$zip.Dispose()}}
}
if($null -eq $valid){throw 'Nao encontrei um WGT de diagnostico previamente assinado. Nao tentarei instalar um pacote sem as assinaturas.'}
Write-Host ''
Write-Host "Encontrado pacote assinado: $($valid.FullName)"
Write-Host "Ultima modificacao: $($valid.LastWriteTime)"
$devices=@(& $sdb devices 2>&1 | Where-Object {$_ -match '^\S+\s+device(?:\s|$)'})
if($devices.Count -ne 1){throw "Esperava 1 TV ligada; encontrei $($devices.Count)."}
$serial=([regex]::Match($devices[0],'^\S+')).Value
Write-Host 'TV SDB detetada, sem mostrar os identificadores.'

Write-Host ''
Write-Host '1/2 — A confirmar autorizacao de instalacao de apps de desenvolvimento...'
& $cli install-permit -s $serial
$permitExit=$LASTEXITCODE
if($permitExit -ne 0){
  Write-Host "Aviso: install-permit terminou com codigo $permitExit. Pode nao ser aplicavel ao modelo."
  Write-Host 'A instalacao continua; guarda o texto do aviso para diagnostico.'
}
Write-Host ''
Write-Host '2/2 — A instalar APENAS o WGT assinado, sem recompilar...'
& $cli install -s $serial -n $valid.Name -- $valid.DirectoryName
$installExit=$LASTEXITCODE
Write-Host ''
if($installExit -eq 0){
  Write-Host 'A CLI indica sucesso. Confirma no menu Apps da Samsung se apareceu Hugo Partner Probe.'
}else{
  Write-Host "A instalacao falhou (codigo $installExit)."
  Write-Host 'Nas Samsung TV o SDB nao permite obter logs de sistema por dlog.'
  Write-Host 'Envia apenas a saida visivel deste comando. Nao partilhes certificados, passwords ou identificadores.'
  Write-Host 'Proximo teste, se continuar a falhar: WGT baseline SEM privilégio Partner, para separar problema de assinatura/DUID do problema de privilegio.'
}
