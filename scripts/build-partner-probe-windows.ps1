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
  [string]$ProfilesXml = '',
  [switch]$Install
)
$ErrorActionPreference='Stop'
$cli=Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb=Join-Path $TizenStudio 'tools\sdb.exe'
if (!(Test-Path -LiteralPath $cli)) { throw "Nao encontrei a CLI Tizen: $cli" }
if ($Install -and !(Test-Path -LiteralPath $sdb)) { throw "Nao encontrei SDB: $sdb" }
# Confirmar que a CLI e o Certificate Manager veem o mesmo perfil.
# Sem isto, o comando "tizen package" pode terminar com codigo 0
# mas gerar um .wgt SEM author-signature.xml e signature1.xml.
function Has-CertificateProfile {
  param([string]$Path, [string]$Name)
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
  try{
    [xml]$doc = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    foreach($node in @($doc.SelectNodes("//*[local-name()='profileitem' or local-name()='profile']"))){
      if($node.GetAttribute('name') -eq $Name){return $true}
    }
  } catch { return $false }
  return $false
}

Write-Host "A validar a configuracao de assinatura Samsung para '$Profile'..."
$existingList = @(& $cli security-profiles list 2>&1)
$cliSeesProfile = ($existingList -match [regex]::Escape($Profile)).Count -gt 0
$candidates = @()
if($ProfilesXml){$candidates += $ProfilesXml}
$candidates += @(
  'C:\tizen-studio-data\profile\profiles.xml',
  (Join-Path $env:USERPROFILE 'tizen-studio-data\profile\profiles.xml'),
  (Join-Path $env:USERPROFILE 'SamsungCertificate\profiles.xml'),
  (Join-Path $env:USERPROFILE 'workspace\.metadata\.plugins\org.tizen.common.sign\profiles.xml'),
  (Join-Path $env:USERPROFILE '.metadata\.plugins\org.tizen.common.sign\profiles.xml')
)
# O certificado pode ter sido criado no VS Code, noutro workspace:
$parentDirs = @(
  (Join-Path $env:USERPROFILE 'Documents'),
  (Join-Path $env:USERPROFILE 'source'),
  (Join-Path $env:USERPROFILE 'SamsungCertificate')
)
foreach($parent in $parentDirs){
  if(Test-Path -LiteralPath $parent -PathType Container){
    $candidates += Join-Path $parent 'profiles.xml'
    $candidates += Join-Path $parent '.metadata\.plugins\org.tizen.common.sign\profiles.xml'
  }
}
$located = @($candidates | Select-Object -Unique | Where-Object { Has-CertificateProfile -Path $_ -Name $Profile })
if($ProfilesXml -and $located.Count -eq 0){
  throw "O ficheiro -ProfilesXml indicado nao existe ou nao contem o perfil '$Profile'. Nao se fez nenhuma alteracao."
}
if($ProfilesXml -or (-not $cliSeesProfile -and $located.Count -eq 1)){
  $selected = $located[0]
  Write-Host "Encontrei o perfil num profiles.xml local. A associar a CLI a esse ficheiro (alteracao persistente na configuracao da CLI, nao nos certificados)."
  & $cli cli-config "default.profiles.path=$selected"
  if($LASTEXITCODE -ne 0){throw 'Falha ao definir default.profiles.path na CLI.'}
  $existingList = @(& $cli security-profiles list 2>&1)
  $cliSeesProfile = ($existingList -match [regex]::Escape($Profile)).Count -gt 0
}
if(-not $cliSeesProfile){
  Write-Host "O perfil '$Profile' existe no Certificate Manager mas NAO esta acessivel a esta CLI Tizen."
  if($located.Count -gt 1){
    Write-Host "Foram encontrados varios profiles.xml com esse perfil; para escolher, passa -ProfilesXml 'caminho\profiles.xml'."
  }elseif($located.Count -eq 0){
    Write-Host "Nao encontrei profiles.xml com esse perfil nos locais habituais."
    Write-Host "Verifica Certificate Manager > perfil SamsungTV_Hugo_2 e o local de profiles.xml. Nao envies XML, .p12 nem passwords."
  }
  Write-Host "Diagnostico adicional SEGURO: & 'C:\tizen-studio\tools\ide\bin\tizen.bat' cli-config -l | Select-String 'profiles.path'"
  throw "Assinatura indisponivel: nao vou gerar outra vez um WGT sem certificado Partner."
}
Write-Host "Perfil '$Profile' confirmado na CLI. Continuar build."

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
