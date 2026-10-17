# Hugo VPN Discovery — teste Tizen 6.0 sem alterar a rede

O utilizador confirmou a instalação e execução do `PartnerPrivilegeProbe` na Samsung QE43Q60AAUXXH (Tizen 6.0, ARMv7). `webapis.sso.getVersion()` devolveu 3.1, uma API que [Samsung marca como Partner](https://developer.samsung.com/smarttv/develop/api-references/samsung-product-api-references/sso-api.html).

**Este teste não é a API nativa VPN.** Investiga apenas se existe uma aplicação do sistema que responda à operação comum `http://tizen.org/appcontrol/operation/setting/vpn`, através de `tizen.application.findAppControl()`, uma API disponível a aplicações Web Samsung. Em paralelo consulta `http://tizen.org/appcontrol/operation/setting` como controlo positivo. **Não chama `launchAppControl()`, não cria TUN e não modifica rotas.**

Documentação:
- [Tizen Native Common Application Controls — VPN Service](https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/app-management/common-appcontrols.md).
- [Samsung TV Web Application API — findAppControl](https://developer.samsung.com/smarttv/develop/api-references/tizen-web-device-api-references/application-api.html).
- [VPN Native Service](https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/connectivity/vpn.md).

## Como instalar

O script `scripts/build-partner-probe-windows.ps1` suporta `-Variant VpnDiscovery` e usa o perfil `SamsungTV_Hugo_2` já registado na CLI. Empacota e instala via caminho curto `%PUBLIC%\TizenProbeStage\HugoVpnDiscovery.wgt`, que funcionou com as duas provas anteriores.

## Interpretação rigorosa

- **VPN encontrada:** existe pelo menos um handler registado para as definições de VPN. Isto não valida que `vpnsvc_init()` funcione num processo de terceiros ou que a TV tenha um serviço VPN utilizável.
- **Nenhum handler:** não existe handler visível à app, **mas a VPN nativa pode existir sem expor esse app control**.
- **Controlo de definições positivo, VPN negativo:** torna mais plausível a ausência do handler específico do VPN no perfil TV.
- **Erro na própria API:** não se consegue retirar conclusão sobre o VPN.

O obstáculo central permanece: a documentação oficial da Samsung Smart TV declara que as TVs de consumo suportam pacotes Web `.wgt`, não `.tpk`; a API VPN C nativa não é exposta ao JavaScript e o certificado Partner não confere automaticamente acesso a root ou encaminhamento global.

## Resultado da Q60A e evolução para a versão 1.0.1 (2026-10-17)

A `Hugo VPN Discovery` versão 1.0.0 instalou-se e abriu na Q60A. Resultado por imagem:
- `Tizen Application API: disponível.`
- `VPN app-control: NotFoundError: Matched Application not found.`
- `Definições (controlo): NotFoundError: Matched Application not found.`

**Interpretação:** não existe um *handler de app control* correspondente visível a esta aplicação para nenhuma das duas operações. O controlo de definições gerais também foi negativo, portanto não validar a ausência de serviço VPN com base nestes erros.

**Versão 1.0.1:** acrescenta um teste mais direto à capacidade anunciada pelo sistema:
- `tizen.systeminfo.getCapability("http://tizen.org/feature/network.vpn")` — capacidade VPN.
- `network.internet` e `network.wifi` — controlos positivos para confirmar que o mecanismo de leitura de capacidades funciona.
- Privilégio `http://tizen.org/privilege/system` declarado na aplicação.
- Mantém os testes AppControl anteriores para comparação.
- Não altera rede, não faz root, não testa `vpnsvc_init()`, não atribui privilégios nativos.

[Documentação nativa oficial Tizen — feature VPN](https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/device/system.md)
e [Samsung — SystemInfo Web API](https://developer.samsung.com/smarttv/develop/api-references/tizen-web-device-api-references/systeminfo-api.html).
A chave `network.vpn` aparece na documentação **genérica/nativa** do Tizen; não está explicitamente enumerada na lista Samsung TV Web de capacidades. É possível que a TV responda `false`, `undefined` ou uma exceção por esse motivo. Distinguir esses casos; não supor que `false` significa impossibilidade de root ou do suporte a VPN modificado.

### Teste da versão 1.0.1

Descarregar a versão mais recente de `scripts/build-partner-probe-windows.ps1` e executar `-Variant VpnDiscovery -Install`. O script empacota com assinatura local Partner e transfere por caminho/ficheiro sem espaços para atualizar a aplicação existente.

### Atenção ao formato de app nativa

A [FAQ Samsung Smart TV — Application Testing](https://developer.samsung.com/smarttv/develop/faq/application-testing.html) afirma que TV comercial aceita apenas `.wgt`, não `.tpk`. Contudo, [Samsung também mantém documentação de criação e implantação de aplicações .NET TV `.tpk`](https://developer.samsung.com/smarttv/develop/tizen-net-tv/getting-started/creating-net-tv-applications.html), e a página [TV Seller Office](https://developer.samsung.com/tv-seller-office/guides/applications/registering-application.html) menciona `.tpk`. Não é correto tratar a impossibilidade de executar código nativo como definitivamente comprovada para esta TV. Precisamos de distinguir políticas de **instalação local**, **distribuição por Seller Office** e **geração/modelo**. Um teste nativo mínimo poderá ser necessário depois de confirmar a capacidade VPN.
