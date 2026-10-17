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
