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

## Decisão após capacidades reais do sistema (Q60A / firmware 2301.1, 17/10/2026)

- `getCapability("http://tizen.org/feature/network.vpn") = false`
- `network.internet = true` e `network.wifi = true` (controlos)
- `findAppControl(setting/vpn)` e `findAppControl(setting)`: `NotFoundError` (nenhum handler visível)
- O `PartnerPrivilegeProbe` instalou e executou `webapis.sso.getVersion() = 3.1`, comprovando que pelo menos a WebAPI SSO Partner está acessível.

**Interpretação:** o firmware atual **não anuncia suporte à funcionalidade VPN**, independentemente do certificado Partner. A app Web não consegue criar VPN global por si. **Não continuar a fazer sondas Web genéricas para tentar descobrir uma VPN escondida.** A presença do motor Go ARMv7 não altera as rotas das outras aplicações.

A [documentação Samsung de capacidades Tizen](https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/device/system.md) afirma que `network.vpn` é true se o dispositivo suporta VPN; `false` é evidência negativa (não prova inexistência de qualquer possibilidade após alteração da plataforma).

**Ponto que ainda merece uma verificação focada:** fontes oficiais apresentam conflito: a [FAQ Smart TV](https://developer.samsung.com/smarttv/develop/faq/application-testing.html) afirma que não aceita `.tpk`, mas a [FAQ Tizen .NET TV](https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html) diz que TVs desde 2019 testam aplicações .NET, e [a documentação de criação da Samsung](https://developer.samsung.com/smarttv/develop/tizen-net-tv/getting-started/creating-net-tv-applications.html) apresenta instalação de `.tpk`. Preparado **NativeRuntimeProbe**, um app C# `tizen60` sem VPN, para verificar se a instalação de nativo está disponível nesta unidade. Automatização experimental via `build-tizen6-native-probe.yml`; não instalar um package ainda não assinado/validado.

**Mesmo que `.tpk` funcione:** a Samsung restringe `DllImport` de bibliotecas nativas do TizenFX e exige aprovação Seller Office para distribuir libs nativas empacotadas, segundo [FAQ .NET TV](https://developer.samsung.com/smarttv/develop/faq/tizen-net-tv.html). A existência de uma app .NET não equivale a acesso VPN do kernel.

**Vulnerabilidade SDB conhecida:** [Bishop Fox, 24/02/2026](https://bishopfox.com/blog/samsung-tizen-os-version-through-9-0) demonstrou execução de comandos como utilizador `sdk` nas versões 5.5/7/8/9 e especulou que 6.0 pode ser afetado. **Não demonstrou root**. Não há, nesta investigação, uma cadeia confirmada para root na Q60A `T-NKLADEUC-2301.1`. Os exemplos públicos dos exploradores Synacktiv referem-se ao Q60T e firmware diferentes.

**Firmware:** A página Samsung de suporte do Q60A lista `2301.1` como firmware publicado em 28/01/2026; não permite inferir se a vulnerabilidade SDB já foi corrigida. Não mudar/downgrade firmware sem cópia de segurança e plano de recuperação.

Próxima escolha **sem desperdiçar tempo**: se o teste TPK falhar ou não oferecer privilégios do sistema, qualquer avanço para VPN de toda a TV terá de investigar efetivamente execução com privilégios OS/kernel (não apenas Partner WebAPI). Essa via permanece incerta e potencialmente arriscada; não se deve apresentar como solução pronta.

## Via de investigação prioritária após NOT_SUPPORTED: Remote PC / CIFS (17/10/2026)

**Resultado real da Q60A:** `vpnsvc_init("hugoprobe", &handle)` retornou `-1073741822 (0xC0000002) = TIZEN_ERROR_NOT_SUPPORTED`. Não insistir em testes de API VPN nem construir mais interfaces.

### Nova evidência de root em outro modelo, ainda não transferível

- [tiz0wn](https://github.com/sebastianspicker/tiz0wn): em 27/09/2026 o investigador validou um **único comando executado como UID 0** por injeção no fluxo **Remote PC / CIFS / Shared Folder** numa **Samsung Q60T (2020), firmware T-NKLDEUC-2743.0**. Trata-se de outro modelo e outra família de firmware, **não existe prova de funcionamento em Q60A T-NKLADEUC-2301.1**. O investigador também não demonstrou persistência ou shell root.
- [Bishop Fox SDB 2026](https://bishopfox.com/blog/samsung-tizen-os-version-through-9-0): revelou injeção de comandos no fluxo SDB, demonstrada em Tizen 5.5/7/8/9, chegando ao utilizador **sdk**, não root. **Tizen 6.0 não foi testado** no artigo, e mesmo sucesso precisaria de escalada separada para manipular interfaces/rotas.
- [Samsung oficial, PC on TV](https://www.samsung.com/pt/support/tv-audio-video/como-usar-a-funcionalidade-pc-on-tv-na-sua-smart-tv-samsung/): TVs 2021 oferecem Home → Fonte → **PC on TV** → **Remote PC** (as opções concretas dependem do modelo). Manual da Q60A menciona acesso a **pastas partilhadas do computador remoto**, mas não confirma a presença do mesmo helper CIFS vulnerável da Q60T.

### Próxima ação com risco quase nulo

**Inspeção exclusivamente visual de funcionalidades, sem introduzir passwords nem ligar a computadores:**

1. Na Q60A, comando **Home** → **Fonte** → **PC on TV** (ou “Remote Access”).
2. Ver se aparece **Remote PC / PC Remoto**; fotografar apenas o menu (evitar IPs, nomes de contas).
3. Se existir, só então verificar se há referência a **pastas partilhadas** na interface. **Não introduzir credenciais reais nem testar payloads nesse momento.**

Se a UI disponibilizar este percurso, o próximo trabalho é comparação **offline** do helper `CIFS` no firmware oficial **T-NKLADEUC-2301.1** da Q60A com os ficheiros/sink documentados no estudo `tiz0wn`. **Apenas depois** discutir um teste de prova no dispositivo, com confirmação explícita e plano de recuperação. Se não disponibilizar Remote PC, priorizar investigação offline da vulnerabilidade SDB sem executar exploits aleatórios.

### Risco e limite técnico

Não copiar exploits da Q60T ou flashear firmware de outra série. Samsung publica T-NKLADEUC 2301.1 para Q60A em 28/01/2026, mas um ficheiro USB oficial não é garantia de recuperação após modificar a partição de arranque. Mesmo root temporário não comprova suporte do kernel para TUN/roteamento; será preciso validá-lo antes de instalar Tailscale como exit node client global.

## Ordem de investigação revista — prioridade à via não-root (17/10/2026)

**Correção de rumo pedida pelo utilizador:** testar primeiro o método **Bishop Fox SDB** para obter comandos como `sdk` sem root; só depois, se necessário e após avaliação de riscos, estudar a via **Remote PC/CIFS com possível UID 0**. Ter encontrado o menu "PC on TV" na Q60A não demonstra vulnerabilidade na versão T-NKLADEUC-2301.1.

1. **SDB não-root, validação mínima:** confirmar requisitos já satisfeitos (Developer Mode, SDB conectado; a shell normal está bloqueada nesta Samsung). Reproduzir apenas um marcador local/consulta `id` com *proof of concept* não persistente e sem reverse shell nem alterações de firmware. **Não assumir** que funciona: [Bishop Fox](https://bishopfox.com/blog/samsung-tizen-os-version-through-9-0) testou Tizen 5.5, 7.0, 8.0 e 9.0, mas **não Tizen 6.0**. Para qualquer tentativa, confirmar explicitamente o consentimento do dono do equipamento e manter o teste de um único comando sem alteração de sistema.
2. Se a execução como `sdk` funcionar, verificar apenas permissões/capacidades e acesso a componentes de rede em modo leitura, comparando com a app .NET (UID 5001; CapEff=0; /dev/net/tun invisível). **Execução como sdk não é root** e não basta para configurar VPN global. Só avançar se revelar capacidade útil para integração com Tailscale.
3. Se a via SDB não permitir gestão de rede, avaliar root Remote PC/CIFS **offline** e com firmware/modelo exatos, antes de qualquer teste de escalada. A prova [tiz0wn](https://github.com/sebastianspicker/tiz0wn) refere-se a Q60T/firmware diferente. Preparar recuperação antes de qualquer modificação persistente.

**Viabilidade relativa:** SDB não-root é o primeiro teste mais barato e reversível, porém pode não resolver o objetivo final. Root daria permissões potencialmente mais relevantes, mas é mais arriscado e não está demonstrado nesta Q60A. Não há percentagens de sucesso defensáveis. Manter clara a distinção entre *obter alguma execução* e *encaminhar o tráfego de todas as apps da televisão*.

## Primeiro teste SDB não-root e correção do PowerShell (17/10/2026)

- Foto do PowerShell após executar `scripts/test-sdb-nonroot-once.ps1`: TV ligada via SDB; a chamada `sdb shell` respondeu `closed`. O PowerShell 5.1 converteu stderr em `NativeCommandError` com `ErrorActionPreference='Stop'` e interrompeu o script na linha 42 **antes de executar `sdb pull`**.
- **Resultado inconclusivo**: `closed` é esperado na Samsung com shell restringida, mesmo nos exemplos vulneráveis da Bishop Fox. Não demonstra execução nem correção.
- Corrigido o helper (commit `d1c79488383ede02523d35dd7835a850969b1af4`) para tolerar erro de stderr/não-zero apenas nas chamadas SDB e **tentar sempre o pull**, mostrando o estado final com interpretação prudente.
- Próximo passo: executar **uma** vez o teste corrigido com token novo. Se o `pull` não encontrar ficheiro, não concluir que a vulnerabilidade está corrigida; avaliar prova alternativa sem alterações da TV. Nunca pedir shell root nem comandos persistentes como parte deste teste.

## Resultado definitivo do teste não-root sdk (17/10/2026)

**Comprovado por fotografia do PowerShell após execução controlada via vulnerabilidade SDB na própria Q60A (Tizen 6.0 / T-NKLADEUC-2301.1):**

```text
Name: cat
Uid: 901 901 901 901
Gid: 901 901 901 901
CapEff: 0000000000000000
CapPrm: 0000000000000000
CapBnd: 0000003fffffffff
Seccomp: 0
CAP_NET_ADMIN sdk: AUSENTE
CAP_NET_RAW sdk: AUSENTE
```

A segunda prova SDB fez `cat</proc/self/status`, escreveu um ficheiro temporário, que foi recuperado via `sdb pull`. Demonstração de execução de comandos como UID 901, não root. O processo efetivamente executado NÃO tem capacidade Linux para administrar diretamente interfaces/rotas da TV. O valor CapBnd não concede efetivamente essa capacidade.

Outras barreiras já demonstradas em testes reais:
- App nativa .NET TV (UID 5001): CapEff=0; /dev/net/tun não visível.
- Tizen WebAPI: `network.vpn=false`.
- lib `libcapi-vpnsvc.so.1` carrega e exporta init/deinit, **mas** `vpnsvc_init` devolve `0xC0000002 = TIZEN_ERROR_NOT_SUPPORTED`.

**Decisão:** Para a meta estrita *encaminhar automaticamente TODO o tráfego das apps da TV Samsung através do Chromecast como exit node Tailscale*, **não há via rootless utilizável demonstrada**. O modo userspace/tsnet/proxy do Tailscale pode gerir ligações de apps que aceitem explicitamente SOCKS/HTTP, mas NÃO intercepta o tráfego de apps alheias. Não confundir com VPN global. Sem `CAP_NET_ADMIN` efetiva ou API de VPN funcional, não investir em interface/integração Tailscale como se essa meta estivesse desbloqueada. Uma interface privilegiada autorizada diferente não foi excluída matematicamente, mas não foi identificada.

A exploração Bishop Fox provou execução, não privilégio para administrar a rede. Não repetir diagnósticos `/proc` arbitrários; as perguntas centrais já foram respondidas. Próximo passo justificável: avaliação estática, específica ao firmware e sem qualquer escrita na TV, da viabilidade de acesso privilegiado/root (por exemplo Remote PC/CIFS) com mecanismo de recuperação definido antes de executar no equipamento. Utilizador pediu esgotar primeiro via sem root; respeitar decisão e não tentar exploração privilegiada sem confirmação explícita.
