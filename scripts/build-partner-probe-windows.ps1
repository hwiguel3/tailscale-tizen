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
Write-Host "Pacote assinado: $($wgts[0].FullName)"
if($Install){
  Write-Host 'A instalar na TV ligada via SDB...'
  & $sdb install $wgts[0].FullName
  if($LASTEXITCODE -ne 0){throw "Instalacao falhou (codigo $LASTEXITCODE); envia a mensagem de erro, sem passwords ou chaves."}
  Write-Host 'Se a instalacao foi aceite, abre Hugo Partner Probe na TV e fotografa o resultado.'
}else{
  Write-Host 'Sem alteracoes na TV. Para instalar, executa o script com -Install.'
}
