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
