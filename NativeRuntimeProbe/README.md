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
