#requires -Version 5.1
<#
  Descarrega o PartnerPrivilegeProbe do fork do GitHub,
  compila a app Web Samsung TV, assina com certificado Partner LOCAL.
  Se -Install for passado, instala o .wgt na TV ligada por SDB.

  Exemplos:
    .\build-partner-probe-windows.ps1 -Variant Baseline -Install
    .\build-partner-probe-windows.ps1 -Variant Partner -Install

  NAO le/exporta certificados nem passwords. Nao executa exploit,
  nao altera firmware, nao chama API de VPN.
#>
[CmdletBinding()]
param(
  [string]$Profile = 'SamsungTV_Hugo_2',
  [string]$TizenStudio = 'C:\tizen-studio',
  [string]$ProfilesXml = '',
  [ValidateSet('Partner','Baseline','VpnDiscovery')][string]$Variant = 'Partner',
  [switch]$Install
)
$ErrorActionPreference='Stop'
$cli=Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb=Join-Path $TizenStudio 'tools\sdb.exe'
if (!(Test-Path -LiteralPath $cli)) { throw "Nao encontrei a CLI Tizen: $cli" }
if ($Install -and !(Test-Path -LiteralPath $sdb)) { throw "Nao encontrei SDB: $sdb" }
# O Certificate Manager da extensao VS Code pode guardar os .p12,
# sem registar um perfil na CLI classica do Tizen Studio.
# A CLI nao assina pacotes sem o seu proprio perfil XML.
# E seguro importar os mesmos .p12 sem gerar um novo certificado.
function Has-CertificateProfile {
  param([string]$Path, [string]$Name)
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
  try {
    [xml]$doc=Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    foreach($node in @($doc.SelectNodes("//*[local-name()='profile' or local-name()='profileitem']"))){
      if($node.GetAttribute('name') -eq $Name){return $true}
    }
  } catch {return $false}
  return $false
}
function Profile-InCli {
  param([string]$Name)
  $result=@(& $cli security-profiles list 2>&1)
  return [bool](@($result | Where-Object { ($_ -replace '^\s+|\s+$','') -eq $Name }).Count -gt 0)
}
Write-Host "A validar a configuracao de assinatura Samsung para '$Profile'..."
$cliSeesProfile=Profile-InCli -Name $Profile
if(-not $cliSeesProfile){
  # Um profiles.xml encontrado noutro workspace nao e necessariamente
  # o ficheiro de perfis da CLI classica. O PowerShell pode ainda retirar
  # as aspas esperadas por 'tizen cli-config' quando o caminho tem espacos.
  # EVITAR mudar default.profiles.path automaticamente: registar os mesmos
  # .p12 na CLI atual e a opcao mais previsivel para o teste A/B.
  $paths=@()
  if($ProfilesXml){$paths+=$ProfilesXml}
  $paths+=@(
    (Join-Path $env:USERPROFILE 'tizen-studio-data\profile\profiles.xml'),
    (Join-Path $env:USERPROFILE 'workspace\.metadata\.plugins\org.tizen.common.sign\profiles.xml'),
    'C:\tizen-studio-data\profile\profiles.xml',
    (Join-Path $env:USERPROFILE 'SamsungCertificate\profiles.xml')
  )
  $matches=@($paths | Select-Object -Unique | Where-Object {
    Has-CertificateProfile -Path $_ -Name $Profile
  })
  if($ProfilesXml -and -not (Has-CertificateProfile -Path $ProfilesXml -Name $Profile)){
    throw "O -ProfilesXml indicado nao contem o perfil '$Profile'."
  }
  if($matches.Count -gt 0){
    Write-Host "Perfil '$Profile' encontrado num XML local, mas nao na CLI atual."
    Write-Host 'Nao vou alterar default.profiles.path automaticamente.'
  }
  Write-Host 'Vou reutilizar os certificados .p12 existentes e registar este perfil diretamente na CLI.'
}
if(-not $cliSeesProfile){
  # O Certificate Manager mostrou os certificados em
  # $env:USERPROFILE\SamsungCertificate\<nome do perfil>.
  $certDirs=@(
    (Join-Path (Join-Path $env:USERPROFILE 'SamsungCertificate') $Profile),
    (Join-Path (Join-Path $env:USERPROFILE 'tizen-studio-data\keystore\samsung') $Profile),
    (Join-Path 'C:\tizen-studio-data\keystore\samsung' $Profile)
  )
  $certDir=$null
  foreach($candidate in $certDirs){
    if((Test-Path -LiteralPath (Join-Path $candidate 'author.p12')) -and
       (Test-Path -LiteralPath (Join-Path $candidate 'distributor.p12'))){
      $certDir=$candidate; break
    }
  }
  if(-not $certDir){
    Write-Host 'Nao encontrei um par author.p12/distributor.p12 na pasta SamsungCertificate ou Tizen Studio.'
    Write-Host 'Abre Certificate Manager e confirma onde guardou os .p12; nao os envies nem envies passwords.'
    throw 'Falta localizar o certificado existente (nenhuma alteracao realizada).'
  }
  Write-Host "Encontrei os certificados Samsung locais na pasta do perfil '$Profile'."
  Write-Host 'Vou REGISTAR os certificados ja existentes na CLI, SEM os recriar.'
  Write-Host 'As passwords serao pedidas localmente, ocultas. Nunca as envies pelo ChatGPT.'
  $authorSecure=Read-Host 'Password do certificado author' -AsSecureString
  $distSecure=Read-Host 'Password do certificado distributor' -AsSecureString
  $p1=[IntPtr]::Zero; $p2=[IntPtr]::Zero
  $authorText=$null; $distText=$null
  try {
    $p1=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($authorSecure)
    $p2=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($distSecure)
    $authorText=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($p1)
    $distText=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($p2)
    # A CLI Tizen aceita -dp (distributor password), nao -P (sintaxe tz).
    # Nota: tizen.bat recebe estas passwords como argumentos locais; nao gravar logs.
    & $cli security-profiles add -n $Profile -a (Join-Path $certDir 'author.p12') -p $authorText -d (Join-Path $certDir 'distributor.p12') -dp $distText
    if($LASTEXITCODE -ne 0){throw "A CLI nao conseguiu registar os .p12 (codigo $LASTEXITCODE)."}
  } finally {
    $authorText=$null; $distText=$null; $authorSecure=$null; $distSecure=$null
    if($p1 -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p1)}
    if($p2 -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p2)}
  }
  $cliSeesProfile=Profile-InCli -Name $Profile
}
if(-not $cliSeesProfile){
  Write-Host "Ainda nao ha perfil '$Profile' utilizavel pela CLI Tizen."
  Write-Host 'Pede ajuda com a mensagem de erro, sem copiar .p12, XML ou passwords.'
  throw 'Assinatura indisponivel. A compilacao foi interrompida.'
}
Write-Host "Perfil '$Profile' confirmado na CLI. A avancar para a compilacao."

$dir=Join-Path ([IO.Path]::GetTempPath()) ('HugoPartnerProbe_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$archive=Join-Path $dir 'code.zip'
$repoUrl='https://github.com/hwiguel3/tailscale-tizen/archive/refs/heads/tizen6-armv7-compat.zip'
Write-Host 'A descarregar o projeto do teu fork no GitHub...'
Invoke-WebRequest -UseBasicParsing -Uri $repoUrl -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $dir
$folder=@(Get-ChildItem -LiteralPath $dir -Directory | Where-Object { $_.Name -like 'tailscale-tizen-*' })
if ($folder.Count -ne 1) { throw 'Nao foi possivel localizar a pasta do repositorio extraido.' }
$probeDir = switch ($Variant) {
  'Baseline' { 'BaselinePrivilegeProbe' }
  'VpnDiscovery' { 'VpnDiscoveryProbe' }
  default { 'PartnerPrivilegeProbe' }
}
Write-Host "Versao de teste: $Variant (projeto $probeDir)"
$proj=Join-Path $folder[0].FullName $probeDir
if (!(Test-Path (Join-Path $proj 'config.xml'))) {throw "Projeto $probeDir/config.xml nao encontrado."}
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
  # Caminhos e nomes com espacos falharam neste equipamento. A mesma app
  # baseline passou a instalar apos copia IDENTICA para nome/caminho curtos.
  # Por isso todas as variantes passam a usar esse procedimento.
  $stageDir=Join-Path $env:PUBLIC 'TizenProbeStage'
  if($stageDir -match '\s'){throw "O caminho de staging contem espacos: $stageDir"}
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
  $stageName = switch($Variant) {
    'Baseline' {'HugoBaselineProbe.wgt'}
    'VpnDiscovery' {'HugoVpnDiscovery.wgt'}
    default {'HugoPartnerProbe.wgt'}
  }
  $stagedWgt=Join-Path $stageDir $stageName
  Copy-Item -LiteralPath $wgts[0].FullName -Destination $stagedWgt -Force
  if((Get-FileHash -LiteralPath $wgts[0].FullName -Algorithm SHA256).Hash -ne
     (Get-FileHash -LiteralPath $stagedWgt -Algorithm SHA256).Hash){
    throw 'A copia do WGT para o caminho curto nao e identica ao original.'
  }
  Write-Host "Pacote assinado verificado e copiado sem alteracoes: $stagedWgt"
  Write-Host '1 TV ligada. A instalar por caminho sem espacos...'
  & $cli install -s $serial -n $stageName -- $stageDir
  $installCode = $LASTEXITCODE
  if($installCode -ne 0){
    throw "Instalacao Tizen falhou (codigo $installCode). Envia o texto do erro acima, ocultando dados pessoais."
  }
  Write-Host "Comando de instalacao terminou com sucesso. Confirma se a app $probeDir aparece na TV."
}else{
  Write-Host 'Sem alteracoes na TV. Para instalar, executa o script com -Install.'
}
