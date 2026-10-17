# Samsung TV Tizen 6.0 / ARMv7: estado de compatibilidade

> **PROTÓTIPO NÃO INSTALÁVEL.** Este ramo existe para validar o motor ARMv7 e estudar uma aplicação **nativa Tizen 6.0**. Não disponibiliza ainda um .tpk instalável nem uma VPN para a TV inteira.

## Televisão de teste

- Samsung Smart TV, perfil `tv`
- `platform_version:6.0`
- `cpu_arch:armv7`
- SDB disponível, **sem acesso root** (`rootonoff_support:disabled`)

## Diferença para o repositório original

- O código original usa `net6.0-tizen8.0` (Tizen 8, .NET 6) e `api-version="8.0"`.
- O Tizen 6 usa a geração **.NET Core 3.1**, com **TizenFX API 8** (`tizen80` no SDK antigo). Para funcionar nesta TV, a aplicação C# tem de ser portada e recompilada.
- O `LocalApi.cs` original recorre a `SocketsHttpHandler.ConnectCallback`, disponível apenas a partir de .NET 5. A API JSON `System.Text.Json.Nodes` e `Task.WaitAsync` também são posteriores a 3.1. **Mudar só o TargetFramework não chega**.
- O `tailscaled` em Go pode ser compilado para `GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0`. É isso que o workflow deste ramo testa.

## GitHub Actions

O workflow `Tizen 6 - ARMv7 engine build` corre no GitHub e disponibiliza um *artifact* chamado `tailscaled-tizen6-armv7-experimental`, contendo o binário e o SHA256. Não é uma aplicação, nem pode ser instalado via `sdb install`.

## O verdadeiro objetivo e a limitação decisiva

O utilizador pretende: **tráfego de todas as aplicações da Samsung TV → Tailscale → Chromecast como exit node**.

O projeto original **não** oferece isto; consegue ligar a TV à tailnet em modo `userspace-networking` e anunciá-la como *exit node* para outros dispositivos. Isto **não** modifica as rotas de tráfego das outras aplicações da televisão. Com o sandbox normal de Tizen e sem permissões de VPN globais nem root, uma aplicação normal não consegue ativar uma VPN para todas as outras apps.

Portanto, só vale a pena investir num port C# completo depois de validar **a execução do motor ARMv7** e se existem **permissões efetivas** de VPN global no modelo. Se a API VPN requer privilégios de parceiro Samsung que não são concedidos, o objetivo de VPN global terá de ser conseguido através de um gateway/router fora da televisão.

## Assinatura Samsung

Mesmo que o projeto venha a gerar um `.tpk`, a Samsung TV necessita de um **certificado de distribuidor Samsung associado ao DUID**. Não colocar ficheiros `.p12`, passwords, ficheiros de perfil ou chaves no repositório (nem em issues/PRs). Em GitHub Actions, só usar segredos se for estritamente necessário e após configurar um procedimento de segurança. Alternativa: assinatura local com certificado existente no Tizen Studio.

## Referências

- Projeto base: https://github.com/tailscale/tailscale-tizen
- Tizen 6 runtime: https://docs.stg.tizen.org/platform/release-notes/tizen-6-0-m1/
- SDK Tizen antigo: https://developer.samsung.com/tizen/blog/en/2019/06/13/using-tizennetsdk-as-sdk-style
- Limitações de rede: README.md do projeto original
