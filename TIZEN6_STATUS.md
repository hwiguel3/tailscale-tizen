# Samsung TV Tizen 6.0 / ARMv7: estado de compatibilidade

> **PROTÓTIPO NÃO INSTALÁVEL.** Este ramo existe para validar o motor ARMv7 e estudar uma aplicação **nativa Tizen 6.0**. Não disponibiliza ainda um .tpk instalável nem uma VPN para a TV inteira.

## Televisão de teste

- Samsung Smart TV, perfil `tv`
- `platform_version:6.0`
- `cpu_arch:armv7`
- SDB disponível, **sem acesso root** (`rootonoff_support:disabled`)

## Diferença para o repositório original

- O código original usa `net6.0-tizen8.0` (Tizen 8, .NET 6) e `api-version="8.0"`.
- O Tizen 6 usa a geração **.NET Core 3.1**. O framework antigo do SDK para o Tizen 6 é **`tizen60`** (não confundir com `net6.0-tizen8.0` nem com o Tizen API level 8). Para funcionar nesta TV, a aplicação C# tem de ser portada e recompilada. Referência: https://developer.samsung.com/tizen/blog/en/2019/06/13/using-tizennetsdk-as-sdk-style
- O `LocalApi.cs` original recorre a `SocketsHttpHandler.ConnectCallback`, disponível apenas a partir de .NET 5. A API JSON `System.Text.Json.Nodes` e `Task.WaitAsync` também são posteriores a 3.1. **Mudar só o TargetFramework não chega**.
- O `tailscaled` em Go pode ser compilado para `GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0`. É isso que o workflow deste ramo testa.

## GitHub Actions

O workflow `Tizen 6 - ARMv7 engine build` corre no GitHub e disponibiliza um *artifact* chamado `tailscaled-tizen6-armv7-experimental`, contendo o binário e o SHA256. Não é uma aplicação, nem pode ser instalado via `sdb install`.

## O verdadeiro objetivo e a limitação decisiva

O utilizador pretende: **tráfego de todas as aplicações da Samsung TV → Tailscale → Chromecast como exit node**.

O projeto original **não** oferece isto; consegue ligar a TV à tailnet em modo `userspace-networking` e anunciá-la como *exit node* para outros dispositivos. Isto **não** modifica as rotas de tráfego das outras aplicações da televisão. Com o sandbox normal de Tizen e sem permissões de VPN globais nem root, uma aplicação normal não consegue ativar uma VPN para todas as outras apps.

Portanto, só vale a pena investir num port C# completo depois de validar **a execução do motor ARMv7** e se existem **permissões efetivas** de VPN global no modelo. Se a API VPN requer privilégios de parceiro Samsung que não são concedidos, o objetivo de VPN global terá de ser conseguido através de um gateway/router fora da televisão.

## Assinatura Samsung

Mesmo que o projeto venha a gerar um `.tpk`, a Samsung TV necessita de um **certificado de distribuidor Samsung associado ao DUID**. O utilizador já confirmou que tem um certificado criado no Tizen Studio; confirmar que é um **perfil Samsung** autorizado para esta televisão (não apenas certificado Tizen genérico). Não colocar ficheiros `.p12`, passwords, ficheiros de perfil ou chaves no repositório (nem em issues/PRs). Em GitHub Actions, só usar segredos se for estritamente necessário e após configurar um procedimento de segurança. Alternativa: assinatura local com certificado existente no Tizen Studio.

## Referências

- Projeto base: https://github.com/tailscale/tailscale-tizen
- Tizen 6 runtime: https://docs.stg.tizen.org/platform/release-notes/tizen-6-0-m1/
- SDK Tizen antigo: https://developer.samsung.com/tizen/blog/en/2019/06/13/using-tizennetsdk-as-sdk-style
- Limitações de rede: README.md do projeto original

## Assinatura local quando existir um .TPK de Tizen 6

Existe um helper PowerShell em `scripts/sign-install-windows.ps1`, por agora **não testado no PC do utilizador**, que permite assinar um `.tpk` já compilado com o certificado **local** e, se pedido, instalar via SDB. Não funciona para o artifact `tailscaled` isolado. Exemplo:

```powershell
.\scripts\sign-install-windows.ps1 -Package ".\Tailscale-unsigned.tpk" -Profile "NOME-DO-PERFIL" -Install
```

O certificado permanece no Windows e **não deve** ser enviado nem publicado no GitHub. O helper usa `tz.exe` (Tizen Core) e fallback `tizen.bat` (CLI clássica); necessita da instalação local do Tizen Studio já disponível.

## Decisão técnica após confirmar certificado Samsung Public (2026-10-17)

O certificado usado para instalar apps é do tipo **Samsung Public**. Não contém direitos Partner.

A documentação oficial do Tizen é **ambígua** quanto à implementação da VPN:
- Lista geral de privilégios nativos: `http://tizen.org/privilege/vpnservice` é rotulado `public`: https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/reference/security-privileges.md .
- Guia `VPN Connections` distingue o acesso ao **VPN service daemon**: afirma explicitamente que precisa do privilégio **Partner** e mostra a declaração `http://developer.samsung.com/tizen/vpnservice`: https://github.com/Samsung/tizen-docs/blob/master/docs/application/native/guides/connectivity/vpn.md .
- O mesmo guia descreve como consultar um handle da VPN e exige consentimento do utilizador para conectar/desconectar. Não prova que o serviço exista no perfil **TV** e na versão **6.0**.
- Na documentação Samsung Smart TV, há materiais de gerações diferentes e restrições diferentes para distribuição de `.tpk`; não assumir suporte deste pacote na TV real até testar: https://developer.samsung.com/smarttv/develop/faq/application-testing.html e https://developer.samsung.com/smarttv/develop/specifications/general-specifications.html .

**Conclusão:** NÃO afirmar que certificado Public por si só prova impossível qualquer API VPN; mas a via documentada para controlar o daemon não está autorizada com este certificado, e nada demonstra túnel de sistema para apps da TV. **Suspender trabalho de port integral e UI** até prova mínima e não destrutiva de disponibilidade/permissão da VPN no televisor. Um binário Go ARMv7 compilado com sucesso NÃO prova instalação ou VPN global.

### Caminho recomendado para o objetivo (sem novos certificados)

Para que as aplicações **nativas Samsung** usem um exit node Tailscale de outro equipamento, uma solução prática é configurar **um gateway/router externo como cliente Tailscale com o exit node selecionado** e ligar a Samsung à rede desse gateway. Referência de implementação em routers GL.iNet: https://docs.gl-inet.com/router/en/4/interface_guide/tailscale/ .

Este gateway tem de ser capaz de servir tráfego de outros equipamentos (encaminhamento + NAT/DNS). **Ter a Tailscale instalada num Chromecast por si só não significa que a TV ligada ao mesmo Wi-Fi tenha o seu tráfego encaminhado.**
