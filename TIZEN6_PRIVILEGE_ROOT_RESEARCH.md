# Samsung TV Tizen 6.0: investigação Partner, root e VPN global

Estado em 2026-10-17: **investigação, sem exploração executada nem root confirmado**.

## Objetivo estrito

Samsung TV (Tizen 6.0 / ARMv7) usa Chromecast na tailnet como **exit node para o tráfego de todas as aplicações da TV**. O binário `tailscaled` em userspace, por si só, **não** altera as rotas das outras apps.

## 1. Certificado Samsung Partner para TESTES

- FAQ oficial Samsung Smart TV: https://developer.samsung.com/smarttv/develop/faq/privileges.html
  - Para **testar** privilégios Partner, criar certificado distribuidor Partner com DUID do dispositivo e assinar a app com ele.
  - Publicar na loja requer aderir a um grupo Partner Seller Office.
- Processo Certificate Manager, Samsung > TV, reutilizar o certificado author existente, criar *novo* distributor com nível Partner, adicionar DUID da TV: https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/creating-certificates.html
- O guia Samsung para certificados demonstra escolha Public/Partner: https://developer.samsung.com/tizen/certificate-signing/creating-certificate.html
- Não publicar nem enviar ficheiros `.p12`, passwords, chaves ou DUID.

**Teste necessário:** criar perfil Partner local e verificar se a Samsung o emite e se a TV aceita uma app de prova que efetivamente exerça o privilégio VPN. Um certificado Partner válido não garante que o serviço exista para TVs.

## 2. VPN service

- Guia Tizen VPN: https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/connectivity/vpn.md
  - Declara `http://developer.samsung.com/tizen/vpnservice`, exige **Partner** para o daemon, requer autorização via aplicação de controlo.
- Tabela de privilégios genéricos Tizen: https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/reference/security-privileges.md
  - Também menciona `http://tizen.org/privilege/vpnservice` como **Public**. Isto pode ser uma diferença entre as APIs e o daemon real.
- A existência da API em documentação geral não prova que o serviço esteja instalado ou acessível no Samsung TV Tizen 6.

## 3. Obtenção de acesso ao sistema, ROOT e firmware

**Investigação divulgada em 2026:**
- Bishop Fox, 'Samsung Tizen OS | Version Through 9.0' (24-02-2026):
  https://bishopfox.com/blog/samsung-tizen-os-version-through-9-0
  - Injeção de comandos através do SDB de Developer Mode, demonstrada em televisores reais Tizen 5.5/7.0/8.0; investigadores também testaram Tizen 9.0 e dizem que Tizen 6.0 é potencialmente afetado, mas **não o testaram**.
  - Os exemplos nos televisores apresentaram `whoami = sdk`, **não root**.
  - Necessita Developer Mode e host na rede autorizado. Vulnerabilidade poderá estar corrigida por firmware posterior.

**ROOT concreto, mas específico do dispositivo:**
- Synacktiv 'Rooting Samsung Q60T Smart TV' (2022):
  https://www.synacktiv.com/sites/default/files/2022-05/Sthack2022_Rooting_Samsung_Q60T_Smart_TV.pdf
- Código demonstrativo: https://github.com/synacktiv/samsung-q60t-exploit
  - Root num modelo Q60T específico (Tizen mais antigo); cadeia dependente de browser, kernel/driver e memória física.
  - **Não há evidência de funcionar no Tizen 6 / firmware deste utilizador**.
  - Trabalho também mostra firmware cifrado; boot seguro / verificação de assinaturas e SMACK/UEP tornam difícil instalar firmware modificado.

## 4. Ordem recomendada: testes de baixo risco

1. Recolher **código do modelo (ex.: QE.../UE...)** e **versão completa de software/firmware** via definições da TV > Assistência > Acerca desta TV. Não publicar número de série, MAC ou DUID.
2. Tentar criar certificado de **distribuidor Partner** para testes no Certificate Manager, preservando author e perfil Public já funcionais; **não substituir nem apagar** o perfil anterior.
3. Investigar se o SDK para o firmware apresenta VPN service e se a plataforma TV o aceita; desenvolver prova de conceito mínima que reporte disponível / indisponível / sem permissão, sem alterar rotas.
4. Só depois comparar a versão do kernel e do firmware com os relatórios Bishop Fox e Synacktiv; qualquer ensaio de exploração deve ter um plano de recuperação.
5. Se conseguir root real, investigar interfaces TUN, `CAP_NET_ADMIN`, rotas globais, DNS e políticas de execução para todas as apps. Mesmo root não garante automaticamente que uma modificação persista após reinício.

### NÃO fazer sem identificar o firmware e capacidade de recuperação

- Flash de firmware modificado ou de outro modelo.
- Tentar mudar partições de arranque, bootloader ou áreas protegidas.
- Executar payloads escritos para um kernel/driver diferente.
- Publicar chaves privadas Samsung ou detalhes identificadores da TV.

O GitHub Actions atual somente demonstra compilação Linux ARMv7 do Tailscale, não instalação, root nem VPN global.

## Dados confirmados por imagem (17/10/2026)

- **Modelo:** Samsung `QE43Q60AAUXXH` (Q60A, versão europeia).
- **Firmware:** `T-NKLADEUC-2301.1`.
- **Sistema via SDB:** Tizen 6.0 / ARMv7, sem root disponível.
- **Certificado:** no Certificate Manager, o perfil `SamsungTV_Hugo_2` aparece ativo e o certificado de distribuição indica `VD DEVELOPER Partner CA Class`, validade até 17/10/2027. Isto é forte evidência de um **distributor Partner genuíno para testes**; ainda não confirma se inclui o DUID da TV nem se a TV autoriza a API VPN.
- **Privacidade:** não reproduzir números de série, MAC, DUID, Smart Hub IDs ou outros identificadores que surgem nas fotos.

**Próximo teste seguro:** confirmar que o certificado Partner contém o DUID do equipamento e que a instalação de um pacote assinado funciona. Depois, validar se `vpnsvc_init` está disponível e autoriza criar um handle em Tizen 6.0 TV, sem alterar rotas ou aplicar privilégios elevados. Evitar tentativas de root ou firmware até esgotar esta via.

## Marco confirmado: chamada Partner WebAPI autorizada na Q60A (17/10/2026)

Imagens recebidas comprovam:
- O WGT `HugoTVP001.PartnerProbe` instalou corretamente usando um nome e caminho de ficheiro **sem espaços**, mantendo o SHA256 do WGT assinado.
- A aplicação abriu na TV e apresentou `Samsung WebAPI base: OK. Versão appcommon: 3.3`.
- `webapis.sso.getVersion()` devolveu **`3.1`**. A [documentação oficial da Samsung](https://developer.samsung.com/smarttv/develop/api-references/samsung-product-api-references/sso-api.html) declara que este método requer o privilégio **Partner** `http://developer.samsung.com/privilege/sso.partner` e pode lançar `SecurityError` sem esse privilégio.
- Isto é **evidência de chamada WebAPI Partner funcional**, mas **não demonstra VPN global nem uma API VPN Web**.

### Próxima verificação sem tocar nas rotas

A [documentação de common app controls nativos do Tizen](https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/app-management/common-appcontrols.md) refere a operação `http://tizen.org/appcontrol/operation/setting/vpn`, que pode existir ou não no dispositivo. A [Web Application API](https://developer.samsung.com/smarttv/develop/api-references/tizen-web-device-api-references/application-api.html) disponibiliza `tizen.application.findAppControl()`, para procurar aplicações registadas para esta operação.

Foi criado o `VpnDiscoveryProbe` para procurar **sem executar** a operação VPN e, como controlo, a operação de definições gerais. Isto **não chama** `vpnsvc_init`, não expõe acesso a TUN, não altera as rotas e um resultado negativo não prova ausência de serviço nativo. O script existente para Windows suporta `-Variant VpnDiscovery -Install`, gera `.wgt` assinado com o perfil local e instala através de caminho sem espaços.

**Limitação ainda ativa:** a [FAQ oficial Smart TV da Samsung](https://developer.samsung.com/smarttv/develop/faq/application-testing.html) afirma que televisões Samsung suportam pacotes Web `.wgt`, **não** pacotes nativos `.tpk`. Um certificado Partner Web não resolve esta distinção; é por isso que testar o alcance real do serviço VPN tem de ser separado da simples autenticação Tailscale.
