#requires -Version 5.1
<#
 Samsung Q60A Tizen 6.0: auditoria exclusivamente de leitura.
 Nao instala, nao modifica firmware, nao liga VPN, nao eleva privilegios.
 Os resultados vazios nao provam que um subsistema nao existe.
 Executar no Windows que tem Tizen Studio e acesso SDB a TV.

 Exemplo:
 .\scripts\check-tv-vpn-readonly.ps1
#>
[CmdletBinding()]
param(
    [string]$Sdb = 'C:\tizen-studio\tools\sdb.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Sdb)) {
    throw "Nao encontrei SDB em $Sdb. Indica -Sdb com o caminho correto."
}
Write-Host '=== Samsung TV: diagnostico VPN em modo SOMENTE LEITURA ==='
$devices = @(& $Sdb devices 2>&1)
$attached = @($devices | Where-Object { $_ -match '\sdevice\s' })
if ($attached.Count -ne 1) {
    Write-Host "Ligacao SDB: esperava 1 dispositivo, encontrei $($attached.Count)."
    Write-Host 'Verifica a TV e executa sdb devices; nao coloques identificadores privados na internet.'
    exit 1
}
Write-Host 'Ligacao SDB: 1 TV detetada (identificadores ocultados).'
# Retail Samsung Q60A reports intershell_support:disabled.
# Do not infer 'no VPN' from silent commands when shell itself is restricted.
$caps = @(& $Sdb capability 2>&1)
if ($caps -match 'intershell_support\s*:\s*disabled') {
    Write-Host 'Shell SDB restrita nesta TV (intershell_support:disabled).'
    Write-Host 'Os comandos id/ls/uname podem devolver vazio; este diagnóstico não testa a VPN.'
    Write-Host 'Continua com PartnerPrivilegeProbe/ (app Web assinada Partner).'
    exit 0
}


function Invoke-ReadOnly {
    param(
       [string]$Title,
       [string]$Command,
       [string]$Filter = ''
    )
    Write-Host ''
    Write-Host "--- $Title ---"
    $lines = @(& $Sdb shell $Command 2>&1)
    $code = $LASTEXITCODE
    if ($Filter) {
        $matches = @($lines | Where-Object { $_ -match $Filter })
        if ($matches.Count -gt 0) {
            $matches | Select-Object -First 35 | ForEach-Object { Write-Host $_ }
        } else {
            Write-Host 'Nenhuma correspondencia visivel (NAO prova ausencia da funcionalidade).'
        }
    } else {
        $lines | Select-Object -First 10 | ForEach-Object { Write-Host $_ }
    }
    if ($code -ne 0) { Write-Host "Acesso indisponivel ou comando nao suportado (codigo $code)." }
}

Invoke-ReadOnly 'Utilizador da shell (nao solicitar root)' 'id'
Invoke-ReadOnly 'Arquitetura do kernel' 'uname -m'
Invoke-ReadOnly 'Bibliotecas com nomes VPN ou TUN em /usr/lib' 'ls /usr/lib' '(?i)vpn|tun'
Invoke-ReadOnly 'Bibliotecas com nomes VPN ou TUN em /usr/lib32' 'ls /usr/lib32' '(?i)vpn|tun'
Invoke-ReadOnly 'Processos VPN conhecidos' 'ps' '(?i)vpn|tun'
Invoke-ReadOnly 'Dispositivo /dev/net/tun' 'ls -l /dev/net/tun'
Invoke-ReadOnly 'Interfaces de rede existentes relacionadas com tun ou tailscale' 'cat /proc/net/dev' '(?i)tun|tap|tailscale'
Write-Host ''
Write-Host 'Fim. Nenhuma alteracao feita. Presenca de ficheiros nao confirma permissao VPN global.'
