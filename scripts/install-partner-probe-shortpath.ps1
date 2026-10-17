#requires -Version 5.1
<#
  Samsung Q60A Tizen 6: testar a instalacao do Hugo Partner Probe ja
  compilado e assinado com SamsungTV_Hugo_2 na tentativa anterior.
  Reutiliza os MESMOS bytes do .wgt mas com caminho e nome sem espacos.
  NAO compila, NAO assina, NAO pede passwords, NAO altera firmware/VPN.
  Ainda nao demonstra que os privilegios Partner foram concedidos.
#>
[CmdletBinding()]
param([string]$TizenStudio = 'C:\tizen-studio')

$ErrorActionPreference = 'Stop'
$cli = Join-Path $TizenStudio 'tools\ide\bin\tizen.bat'
$sdb = Join-Path $TizenStudio 'tools\sdb.exe'
if (-not (Test-Path -LiteralPath $cli)) { throw "Tizen CLI nao encontrada: $cli" }
if (-not (Test-Path -LiteralPath $sdb)) { throw "SDB nao encontrado: $sdb" }
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Os pacotes antigos podem estar sem assinatura; so escolher um com
# assinaturas e config.xml pertencente a app Partner Probe, nao Baseline.
$files = @(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'HugoPartnerProbe_*' -ErrorAction SilentlyContinue |
   ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter '*.wgt' -ErrorAction SilentlyContinue } |
   Sort-Object LastWriteTime -Descending)
$source = $null
foreach ($item in $files) {
    $zip = $null
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($item.FullName)
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
        $missing = @('config.xml','author-signature.xml','signature1.xml') |
           Where-Object { $names -notcontains $_ }
        if ($missing.Count -gt 0) { continue }
        $entry = $zip.GetEntry('config.xml')
        if ($null -eq $entry) { continue }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        try { $config = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($config -match 'HugoTVP001\.PartnerProbe' -and
            $config -match 'http://developer\.samsung\.com/privilege/sso\.partner') {
            $source = $item
            break
        }
    }
    catch { }
    finally { if ($null -ne $zip) { $zip.Dispose() } }
}

if ($null -eq $source) {
   throw 'Nao encontrei o WGT Partner Probe assinado e com sso.partner. Nao execute uma recompilacao ate verificarmos a pasta.'
}

# C:\Users\Public e normalmente um caminho sem espacos. Mesmo .wgt,
# novo nome do arquivo, assinatura e config interna inalterados.
$folder = Join-Path $env:PUBLIC 'TizenProbeStage'
if ($folder -match '\s') {
   throw "O caminho da pasta de teste tem espacos: $folder"
}
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$target = Join-Path $folder 'HugoPartnerProbe.wgt'
Copy-Item -LiteralPath $source.FullName -Destination $target -Force
if ((Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
    throw 'A copia do pacote nao e identica ao original: abortado.'
}
Write-Host '=== Hugo Partner Probe: teste de instalacao com caminho sem espacos ==='
Write-Host 'O WGT ja assinado foi copiado sem alteracoes (SHA256 igual).'
Write-Host 'O manifesto inclui sso.partner; isto NAO testa a API VPN.'

$devices = @(& $sdb devices 2>&1 | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
if ($devices.Count -ne 1) { throw "Esperava 1 Samsung TV ligada por SDB; encontrei $($devices.Count)." }
$serial = ([regex]::Match($devices[0], '^\S+')).Value
Write-Host 'TV ligada via SDB; a tentar instalacao do pacote Partner...'
& $cli install -s $serial -n 'HugoPartnerProbe.wgt' -- $folder
$installExit = $LASTEXITCODE
Write-Host ''
if ($installExit -eq 0) {
    Write-Host 'INSTALACAO CONCLUIDA. Abre Hugo Partner Probe na Samsung.'
    Write-Host 'Fotografa as linhas Samsung WebAPI base e Partner SSO.'
    Write-Host 'Nota: instalar nao confirma o funcionamento da API Partner e nao significa VPN global.'
} else {
    Write-Host "INSTALACAO FALHOU: codigo CLI $installExit."
    Write-Host 'Como a Baseline instalou por este metodo, a proxima analise sera permissao sso.partner e certificado Partner.'
    Write-Host 'Envia apenas o texto da falha. Nao envies dados identificadores, certificados nem passwords.'
}
