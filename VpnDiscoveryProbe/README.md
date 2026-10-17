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
