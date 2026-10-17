#requires -Version 5.1
<#
  Assina um .TPK já compilado usando o certificado Samsung LOCAL.
  Não envia certificados nem passwords para o GitHub.

  Exemplo (apenas quando houver um .tpk da app Tizen 6):
    .\scripts\sign-install-windows.ps1 -Package ".\Tailscale-unsigned.tpk" -Profile "meu-perfil"
    .\scripts\sign-install-windows.ps1 -Package ".\Tailscale-unsigned.tpk" -Profile "meu-perfil" -Install

  IMPORTANTE: O artifact 'tailscaled-tizen6-armv7-experimental'
  é apenas um executável, NÃO um .tpk. Não o passar a este script.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Package,
  [Parameter(Mandatory=$true)][string]$Profile,
  [string]$TizenStudio = "C:\tizen-studio",
  [switch]$Install,
  [string]$Device = ""
)

$ErrorActionPreference = "Stop"
$pkgFull = (Resolve-Path -LiteralPath $Package).Path
if (-not $pkgFull.EndsWith(".tpk", [StringComparison]::OrdinalIgnoreCase)) {
  throw "Este script só aceita um .tpk da aplicação. O binário tailscaled isolado não é um .tpk."
}
$base = [IO.Path]::GetFileNameWithoutExtension($pkgFull)
$out = Join-Path ([IO.Path]::GetDirectoryName($pkgFull)) "$base.samsung-signed.tpk"
$tz = Join-Path $TizenStudio "tools\tizen-core\tz.exe"
$tizenBat = Join-Path $TizenStudio "tools\ide\bin\tizen.bat"
$sdb = Join-Path $TizenStudio "tools\sdb.exe"

Write-Host "A assinar .tpk com o perfil local '$Profile' (não são transferidas credenciais)."
if (Test-Path -LiteralPath $tz) {
  & $tz pack -t tpk -s $Profile -b $pkgFull -o $out
  if ($LASTEXITCODE -ne 0) { throw "A assinatura com tz falhou (código $LASTEXITCODE)." }
} elseif (Test-Path -LiteralPath $tizenBat) {
  # A CLI clássica re-assina o próprio pacote de entrada. Usar cópia de saída.
  Copy-Item -LiteralPath $pkgFull -Destination $out -Force
  & $tizenBat package -t tpk -s $Profile -- $out
  if ($LASTEXITCODE -ne 0) { throw "A assinatura com tizen falhou (código $LASTEXITCODE)." }
} else {
  throw "Não encontrei tz.exe nem tizen.bat em '$TizenStudio'. Corrige -TizenStudio."
}
if (-not (Test-Path -LiteralPath $out)) {
  throw "A ferramenta terminou mas não encontrei o .tpk assinado em $out."
}
Write-Host "TPK assinado: $out"

if ($Install) {
  if (-not (Test-Path -LiteralPath $sdb)) { throw "Não encontrei sdb.exe em $sdb" }
  if ($Device) {
    Write-Host "A instalar no dispositivo $Device"
    & $sdb -s $Device install $out
  } else {
    Write-Host "A instalar no único dispositivo ligado a sdb."
    & $sdb install $out
  }
  if ($LASTEXITCODE -ne 0) { throw "A instalação SDB falhou (código $LASTEXITCODE)." }
  Write-Host "Instalação concluída. A execução real da app tem de ser validada na TV."
}
