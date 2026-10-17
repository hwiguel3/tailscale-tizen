#requires -Version 5.1
<#
  Descarrega o PartnerPrivilegeProbe do fork do GitHub,
  compila a app Web Samsung TV, assina com certificado Partner LOCAL.
  Se -Install for passado, instala o .wgt na TV ligada por SDB.

  Exemplo:
    .\build-partner-probe-windows.ps1 -Install

  NAO le/exporta certificados nem passwords. Nao executa exploit,
  nao altera firmware, nao chama API de VPN.
#>
[CmdletBinding()]
param(
  [string]$Profile = 'SamsungTV_Hugo_2',
  [string]$TizenStudio = 'C:\tizen-studio',
  [switch]$Install
)
$ErrorActionPreference='Stop'
$cli=Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb=Join-Path $TizenStudio 'tools\sdb.exe'
if (!(Test-Path -LiteralPath $cli)) { throw "Nao encontrei a CLI Tizen: $cli" }
if ($Install -and !(Test-Path -LiteralPath $sdb)) { throw "Nao encontrei SDB: $sdb" }
$dir=Join-Path ([IO.Path]::GetTempPath()) ('HugoPartnerProbe_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$archive=Join-Path $dir 'code.zip'
$repoUrl='https://github.com/hwiguel3/tailscale-tizen/archive/refs/heads/tizen6-armv7-compat.zip'
Write-Host 'A descarregar o projeto do teu fork no GitHub...'
Invoke-WebRequest -UseBasicParsing -Uri $repoUrl -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $dir
$folder=@(Get-ChildItem -LiteralPath $dir -Directory | Where-Object { $_.Name -like 'tailscale-tizen-*' })
if ($folder.Count -ne 1) { throw 'Nao foi possivel localizar a pasta do repositorio extraido.' }
$proj=Join-Path $folder[0].FullName 'PartnerPrivilegeProbe'
if (!(Test-Path (Join-Path $proj 'config.xml'))) {throw 'Projeto PartnerPrivilegeProbe/config.xml nao encontrado.'}
Write-Host 'A compilar Web app TV Tizen 6.0...'
& $cli build-web -- $proj
if($LASTEXITCODE -ne 0){throw "A compilacao Web falhou (codigo $LASTEXITCODE)."}
$build=Join-Path $proj '.buildResult'
if (!(Test-Path $build)){throw "Pasta de compilacao nao encontrada: $build"}
Write-Host "A assinar Web app com perfil Samsung Partner local: $Profile"
& $cli package -t wgt -s $Profile -- $build
if($LASTEXITCODE -ne 0){throw "Assinatura/pacote falhou (codigo $LASTEXITCODE)."}
$wgts=@(Get-ChildItem -LiteralPath $build -Filter '*.wgt' -File)
if($wgts.Count -ne 1){throw "Esperava 1 pacote .wgt em $build. Encontrados: $($wgts.Count)."}
Write-Host "Pacote criado: $($wgts[0].FullName)"
# Os avisos "Not found tizen signature file" referem-se frequentemente ao
# projeto de entrada ainda por assinar. Verificar assinaturas DENTRO do .wgt.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($wgts[0].FullName)
try {
  $names = @($zip.Entries | ForEach-Object { $_.FullName })
  foreach($required in @('config.xml','author-signature.xml','signature1.xml')) {
    if($names -notcontains $required){
      throw "O WGT nao contem $required. A assinatura esta incompleta; NAO instalar."
    }
  }
  Write-Host 'Pacote validado: config.xml, author-signature.xml e signature1.xml presentes.'
} finally {
  $zip.Dispose()
}
if($Install){
  Write-Host 'A instalar com a CLI oficial do Tizen (em vez de sdb install)...'
  $connected = @(& $sdb devices | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
  if($connected.Count -ne 1) {
    throw "Esperava exatamente uma TV ligada no SDB. Encontrei $($connected.Count)."
  }
  $serial = ([regex]::Match($connected[0], '^\S+')).Value
  Write-Host '1 TV ligada. A executar tizen install -s SERIAL -n WGT -- DIRETORIO.'
  # A sintaxe documentada Samsung para WGT e: tizen install -s SERIAL
  # -n nome.wgt -- pasta. Nao passar o caminho completo como -n.
  & $cli install -s $serial -n $wgts[0].Name -- $build
  $installCode = $LASTEXITCODE
  if($installCode -ne 0){
    throw "Instalacao Tizen falhou (codigo $installCode). Envia o texto do erro acima, ocultando dados pessoais."
  }
  Write-Host 'Comando de instalacao terminou com sucesso. Confirma se a app aparece na TV.'
}else{
  Write-Host 'Sem alteracoes na TV. Para instalar, executa o script com -Install.'
}
