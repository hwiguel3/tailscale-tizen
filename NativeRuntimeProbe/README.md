# Hugo Native Runtime Probe — Tizen 6.0 / Samsung Q60A

**Teste de viabilidade, não aplicação VPN.** Este projeto isola uma única pergunta: uma Samsung Q60A real com Tizen 6.0 aceita e inicia um **.tpk** Tizen .NET compilado para `tizen60`?

Não instala nenhum motor Tailscale, não invoca `vpnsvc_init()`, não abre TUN, não muda rotas nem mexe em firmware. Usa `Tizen.NET.Sdk/1.0.8` com `TargetFramework=tizen60`, conforme a [Samsung descreve para versões antigas](https://developer.samsung.com/tizen/blog/en/2019/06/13/using-tizennetsdk-as-sdk-style).

## Porque testar

A Samsung documenta que a [API VPN nativa](https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/connectivity/vpn.md) é C, enquanto o SDK de TV Web não a expõe. A [FAQ de testes](https://developer.samsung.com/smarttv/develop/faq/application-testing.html) diz que TVs comerciais só suportam `.wgt`, mas o [FAQ específico .NET TV](https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html) diz que aplicações .NET são testáveis em Samsung TV desde 2019 e [este guia](https://developer.samsung.com/smarttv/develop/tizen-net-tv/getting-started/creating-net-tv-applications.html) explica `.tpk`.

Precisamos de uma prova no **modelo específico** em vez de generalizar.

## Estado da capacidade VPN

Em 17/10/2026, o `VpnDiscoveryProbe` na Q60A devolveu:
- `http://tizen.org/feature/network.vpn: false`
- `network.internet: true`
- `network.wifi: true`
- Operações `setting/vpn` e `setting`: `NotFoundError`

Isto indica fortemente que **a VPN nativa não é suportada pela plataforma da TV tal como está**, embora `false` não prove que modificações privilegiadas sejam impossíveis. Uma instalação .NET bem-sucedida também não basta: [a Samsung limita DllImport em bibliotecas do TizenFX](https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html) e bibliotecas nativas empacotadas exigem acesso adicional a grupos Partner Seller Office.

## Build

A workflow GitHub Actions `build-tizen6-native-probe.yml` tenta compilar este projeto com .NET Core 3.1 no Linux. O resultado é experimental; qualquer erro de compilação será estudado na Action e não obriga a instalar .NET no Windows.

O **pacote de GitHub Actions, se produzido, não tem necessariamente assinatura Samsung adequada** à TV. **Não instalar nenhum artefacto ainda** sem verificar pacote e assiná-lo localmente com o perfil Samsung autorizado para o DUID. Não fazer upload de certificados, chaves ou passwords.

Mesmo com o pacote corretamente assinado, só fazer uma tentativa de instalação segura, guardando a mensagem de erro. **Não** usar `sdb root`, exploits ou flash de firmware nesta etapa.

## Referências

- https://developer.samsung.com/smarttv/develop/specifications/general-specifications.html
- https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html
- https://developer.samsung.com/smarttv/develop/faq/application-testing.html

## Resultado CI (17/10/2026)

**GitHub Actions run [39041583763](https://github.com/hwiguel3/tailscale-tizen/actions/runs/39041583763) terminou com sucesso**, incluindo dotnet build com .NET Core 3.1 e Tizen.NET.Sdk/1.0.8, verificação da presença de um .tpk e upload do artefacto **native-tizen60-unverified-test-package**. Confirma que o código-fonte compila num SDK antigo para Tizen 6; **não confirma compatibilidade com a TV, privilégios de kernel nem VPN global**.

O artefacto tem assinatura experimental do CI, **não** o certificado Samsung para o DUID. Para testar instalação real, transferir o ZIP da página de run no GitHub para a pasta Downloads e executar no Windows:

    $url="https://raw.githubusercontent.com/hwiguel3/tailscale-tizen/tizen6-armv7-compat/scripts/install-native-tizen60-test.ps1"
    $script="$env:TEMP\install-native-tizen60-test.ps1"
    Invoke-WebRequest -Uri $url -OutFile $script
    & $script

O script verifica o manifesto, re-assina localmente com SamsungTV_Hugo_2 via tizen package -t tpk -s ... -- pacote.tpk, verifica duas assinaturas e tenta **uma única instalação** via CLI com caminho/ficheiro sem espaços. A [documentação oficial da Tizen CLI](https://github.com/Samsung/tizen-docs/blob/master/docs/sdk-tools/baseline-sdk/common-tools/command-line-interface.md) confirma re-assinatura de pacote existente. Nenhuma chave é enviada ao GitHub. A assinatura local ainda não foi testada na máquina do utilizador.

Não tentar instalar o artefacto de CI antes da assinatura local. Se falhar, guardar erro e parar.

## Confirmacao no televisor e diagnóstico nativo 0.2 (17/10/2026)

O utilizador mostrou o TPK com ID com.hugo.nativeprobe instalado e executado na Q60A Tizen 6.0: o ecrã da aplicação NUI apareceu. Isto comprova suporte efetivo a apps .NET TPK neste modelo, **não acesso root nem VPN global**.

A nova versão **0.2.0** faz somente leituras de sistema no próprio processo: existência visível de /dev/net/tun (sem o abrir), /proc/self/status para UID, CapEff e CAP_NET_ADMIN (bit 12), NoNewPrivs, versão de kernel, nomes de interfaces sem IP/MAC e pesquisa superficial de bibliotecas VPN em pastas públicas. Não chama bibliotecas nativas, não muda rotas, não inicia VPN e não faz root.

Compilação e artefacto **confirmados** nas [GitHub Actions #39042322994](https://github.com/hwiguel3/tailscale-tizen/actions/runs/39042322994): job completo SUCCESS, artefacto ZIP **native-tizen60-network-diagnostics** (~19 KB).

### Para instalar v0.2

1. Descarregar para Downloads o ZIP **native-tizen60-network-diagnostics** em https://github.com/hwiguel3/tailscale-tizen/actions/runs/39042322994 (não extrair).
2. No PowerShell:

    $url = "https://raw.githubusercontent.com/hwiguel3/tailscale-tizen/7afa15f690e6166ae8ae0338c35a00d1af9b4da9/scripts/install-native-tizen60-test.ps1"
    $script = "$env:TEMP\install-native-network-probe.ps1"
    Invoke-WebRequest -Uri $url -OutFile $script
    & $script

3. O script verifica manifesto e re-assina LOCALMENTE com certificado Samsung Partner já configurado. Não carregar P12, passwords ou DUID.
4. Abrir Hugo Native Network Probe e fotografar. O teste não identifica IP ou MAC.

CAP_NET_ADMIN ausente significa que o processo não tem a capacidade Linux para gerir rotas/interfaces diretamente, mas não prova ausência de qualquer serviço privilegiado. A Samsung proíbe DllImport para bibliotecas TizenFX em apps .NET TV e exige Seller Office Partner para bibliotecas nativas empacotadas: https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html .

## Resultado v0.2 na Samsung real e teste v0.3 (17/10/2026)

A fotografia da app TPK no televisor confirmou:

- Kernel **4.1.10**, UID(s) do processo **5001 5001 5001 5001**, CapEff=0000000000000000; portanto **CAP_NET_ADMIN ausente**.
- **/dev/net/tun não visível** ao processo; isto não prova que o kernel não suporte TUN, apenas que este processo não vê o caminho.
- Interfaces visíveis **wlan0, p2p0, eth0**.
- Bibliotecas com nome vpn visíveis: **libcapi-vpnsvc.so.1** e **libcapi-vpnsvc.so.1.1.0**. Podem ser a mesma biblioteca (soname/versão via symlink), não concluir que existem dois serviços separados.
- NoNewPrivs não visível na leitura de /proc/self/status.

**Interpretação:** Uma app Tizen .NET assinada com certificado Partner continua confinada ao sandbox da Samsung, sem a capacidade Linux necessária para gerir interfaces/rotas diretamente. A presença da biblioteca CAPI VPN no firmware não implica que o daemon esteja em execução nem autorizado, especialmente porque a Web SystemInfo anunciou network.vpn=false.

### v0.3 — confirmar acessibilidade ao carregador de bibliotecas (NÃO iniciar VPN)

Criei v0.3 que tenta `NativeLibrary.TryLoad("libcapi-vpnsvc.so.1", out handle)`, depois, se tiver sucesso, `TryGetExport("vpnsvc_init")` e `TryGetExport("vpnsvc_deinit")`, e por fim `Free(handle)`. **Não chama `vpnsvc_init`, não cria túnel, não abre /dev/net/tun e não altera rotas**. A operação de carregar uma .so pode executar inicializadores internos da biblioteca e pode falhar ou causar instabilidade sob as políticas Samsung; fechar a app se houver problemas. Não é uma tentativa de ultrapassar as autorizações de TV nem garante que interop seja permitida.

A [Samsung TV .NET Q&A](https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html) afirma que é proibido usar DllImport para bibliotecas TizenFX do sistema. `NativeLibrary.TryLoad` é um diagnóstico do carregador .NET Core 3.1, **não uma autorização para invocar a API VPN**. Se carregar, ainda faltam privilégio de daemon e função VPN permitida; se falhar, não identificar automaticamente se é por sandbox, dependências ou arquitetura.

GitHub Actions v0.3: [run #39042792492](https://github.com/hwiguel3/tailscale-tizen/actions/runs/39042792492) **SUCCESS**, artifact **native-tizen60-vpn-loader-diagnostics**. Artefacto não assinado com os certificados do utilizador no GitHub. Descarregar ZIP para Downloads e assinar localmente com script `scripts/install-native-tizen60-test.ps1` (atualizado).

Depois de instalar/abrir na Samsung, fotografar a linha **Carregamento vpnsvc:**. Não executar tentativas de vpnsvc_init ou root enquanto não compreendermos as permissões e o risco de interromper a conectividade.
