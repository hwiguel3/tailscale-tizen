#requires -Version 5.1
<#
 Hugo - Samsung Q60A T-NKLADEUC (firmware 2301.1)
 MSDU11 HEADER COMPATIBILITY TEST, read-only and bounded.

 Reads only the first <512 KiB of upgrade.msd directly from the ZIP
 (without extracting the ~1.4GB package). Confirms MSDU11 structure,
 then tests whether a published Synacktiv Q60T passphrase can decrypt
 the *metadata header* only. No partitions, kernel, or firmware are
 changed, uploaded, or extracted.

 The published upstream Python script is fetched only as TEXT for its
 passphrase byte-array; it is NOT executed. No private keys are used.
 Source: https://github.com/synacktiv/samsung-q60t-exploit
#>
[CmdletBinding()]
param([string]$ZipPath = (Join-Path $env:USERPROFILE 'Downloads\T-NKLADEUC.zip'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Range([bool]$Condition,[string]$Message) {
  if (-not $Condition) { throw $Message }
}

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
  throw "Firmware ZIP nao encontrado: $ZipPath"
}

$zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
  $entry = $zip.GetEntry('T-NKLADEUC/image/upgrade.msd')
  if ($null -eq $entry) { throw 'upgrade.msd nao encontrado na estrutura esperada.' }
  Write-Host '=== FIRMWARE ORIGINAL, SEM EXTRACAO ==='
  Write-Host ('ZIP: ' + [IO.Path]::GetFileName($ZipPath))
  Write-Host ('upgrade.msd: ' + $entry.Length + ' bytes')
  $stream = $entry.Open()
  $reader = New-Object System.IO.BinaryReader($stream)
  try {
    $magic = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(6))
    Assert-Range ($magic -eq 'MSDU11') "Cabecalho inesperado: $magic"
    $crc = $reader.ReadUInt32()
    $unk0 = $reader.ReadUInt64()
    $sectionsCount = [int]$reader.ReadUInt32()
    Assert-Range ($sectionsCount -gt 0 -and $sectionsCount -le 50) "Numero de secoes nao esperado: $sectionsCount"
    $sections = @()
    for ($i=0; $i -lt $sectionsCount; $i++) {
      $sectionId = $reader.ReadUInt32()
      $offset = $reader.ReadUInt64()
      $length = $reader.ReadUInt64()
      $sections += [pscustomobject]@{Id=$sectionId;Offset=$offset;Size=$length}
    }
    $headersCount = $reader.ReadUInt32()
    $headerSize = $reader.ReadUInt32()
    $unknown1 = $reader.ReadUInt32()
    $encSize = [int]$reader.ReadUInt32()
    $modelSize = [int]$reader.ReadByte()
    Assert-Range ($modelSize -gt 0 -and $modelSize -lt 100) "Nome de modelo invalido ($modelSize)"
    $model = [Text.Encoding]::ASCII.GetString($reader.ReadBytes($modelSize))
    $unknown2 = $reader.ReadUInt64()
    $salted = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(8))
    Assert-Range ($salted -eq 'Salted__') "Salted__ nao encontrado; variante inesperada."
    $salt = $reader.ReadBytes(8)
    $cipherLen = $encSize - 24
    Assert-Range ($cipherLen -gt 0 -and $cipherLen -le 512KB -and ($cipherLen % 16) -eq 0) "Dimensao do header encriptado inesperada: $cipherLen"
    $encrypted = $reader.ReadBytes($cipherLen)
    Assert-Range ($encrypted.Length -eq $cipherLen) "Leitura parcial do header encriptado."
  } finally { $reader.Dispose() }

  Write-Host ('Formato: ' + $magic)
  Write-Host ('Modelo no header: ' + $model)
  Write-Host ('Secoes declaradas: ' + $sectionsCount)
  Write-Host ('Blocos de header: ' + $headersCount)
  Write-Host ('Metadados encriptados: ' + $cipherLen + ' bytes')
  $outOfBounds = @($sections | Where-Object {
    $_.Offset -gt [uint64]$entry.Length -or $_.Size -gt [uint64]$entry.Length -or
    $_.Offset + $_.Size -gt [uint64]$entry.Length
  })
  if ($outOfBounds.Count -gt 0) {
    Write-Host 'AVISO: algumas secoes ultrapassam os limites da entrada. Nao extrair.'
    return
  }
  if ($model -ne 'T-NKLADEUC') {
    Write-Host 'AVISO: nome de modelo inesperado; nao prosseguir para teste de chave.'
    return
  }

  Write-Host ''
  Write-Host '=== TESTE DE COMPATIBILIDADE COM DESCODIFICADOR PUBLICADO ==='
  $srcUrl='https://raw.githubusercontent.com/synacktiv/samsung-q60t-exploit/main/firmware/decrypt.py'
  Write-Host 'A obter a definicao publica da chave (codigo NAO executado)...'
  try {
    $source=(Invoke-WebRequest -Uri $srcUrl -UseBasicParsing -TimeoutSec 20).Content
  } catch {
    Write-Host ('Fonte oficial indisponivel: ' + $_.Exception.Message)
    Write-Host 'Estrutura MSDU11 validada; teste da chave nao executado.'
    return
  }
  $match=[regex]::Match($source,'(?s)passphrase\s*=\s*bytes\(\[\s*(.*?)\s*\]\s*\)')
  if(-not $match.Success){
    Write-Host 'O formato da definicao da chave mudou no repositorio. Nao foi possivel testar.'
    return
  }
  $hexMatches=[regex]::Matches($match.Groups[1].Value, '0x([0-9a-fA-F]{2})')
  Assert-Range ($hexMatches.Count -gt 10 -and $hexMatches.Count -lt 500) 'A chave publica nao foi identificada de forma fiavel.'
  [byte[]]$passphrase=@(foreach($h in $hexMatches){[Convert]::ToByte($h.Groups[1].Value,16)})

  $md5=[Security.Cryptography.MD5]::Create()
  try {
    [byte[]]$key=$md5.ComputeHash($passphrase)
    [byte[]]$iv=$md5.ComputeHash($salt)
  } finally {$md5.Dispose()}

  $aes=[Security.Cryptography.Aes]::Create()
  $aes.Mode=[Security.Cryptography.CipherMode]::CBC
  $aes.Padding=[Security.Cryptography.PaddingMode]::None
  $aes.KeySize=128
  $aes.Key=$key
  $aes.IV=$iv
  try {
    $decryptor=$aes.CreateDecryptor()
    try {
      [byte[]]$plain=$decryptor.TransformFinalBlock($encrypted,0,$encrypted.Length)
    } finally {$decryptor.Dispose()}
  } finally {$aes.Dispose()}

  # Metadata is binary TLV, so a plain text 'magic' is not guaranteed.
  # A positive result means we found multiple expected section names.
  $asText=[Text.Encoding]::ASCII.GetString($plain)
  $expected=@('uImage','platform.img','dtb.bin','secos.bin','seret.bin','ddr.init')
  $names=@($expected | Where-Object {$asText.Contains($_)})
  Write-Host ('Nomes de secoes reconhecidos no header: ' + $(if($names.Count -gt 0){$names -join ', '}else{'nenhum'}))
  if($names.Count -ge 2){
    Write-Host 'RESULTADO: chave publica COMPATIVEL com os metadados deste firmware.'
    Write-Host 'Podemos planear extrair apenas o kernel (uImage) em fase seguinte.'
  }else{
    Write-Host 'RESULTADO: compatibilidade da chave NAO CONFIRMADA.'
    Write-Host 'Pode ser chave diferente, layout diferente ou outros nomes. Nao extrair tudo.'
  }
  Write-Host 'Nao foi alterado nem copiado nenhum ficheiro de firmware.'
} finally {$zip.Dispose()}
