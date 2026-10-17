# Hugo Partner Probe (Samsung Smart TV Tizen 6.0)

**Teste de segurança mínimo, separado da aplicação Tailscale.** A Samsung Q60A só expõe shell SDB restrita: `intershell_support:disabled`; não voltar a tentar usar `sdb shell id` / `uname` como diagnóstico conclusivo.

## O que testa

Aplicação Web (`.wgt`) que usa **apenas**:
- `webapis.appcommon.getVersion()`: confirma que a biblioteca Samsung WebAPI está acessível.
- `webapis.sso.getVersion()`: a [Samsung SSO API](https://developer.samsung.com/smarttv/develop/api-references/samsung-product-api-references/sso-api.html) é documentada com privilégio **Partner** `http://developer.samsung.com/privilege/sso.partner`. Não lê dados de contas nem altera a TV. A ausência da API por modelo/firmware é inconclusiva quanto à assinatura.

**Não** testa `vpnsvc_init`, nem cria VPN global. Apps Web não têm acesso à API C nativa de VPN.

## Instalação recomendada com ferramentas já existentes

1. Fazer download do branch `tizen6-armv7-compat` do fork no GitHub (Code > Download ZIP) e extrair.
2. Abrir **apenas esta pasta** `PartnerPrivilegeProbe/` com o VS Code configurado com extensão Tizen Web. A aplicação tem `config.xml` e `index.html`.
3. Confirmar que o perfil ativo no Certificate Manager é **SamsungTV_Hugo_2**, certificado **Samsung Partner**, e que o DUID do equipamento consta nesse perfil. Não enviar o DUID ou passwords.
4. Compilar e criar um `.wgt` assinado usando os comandos de build/package da extensão Tizen, como já foi feito para a aplicação Web anterior. Se a extensão não reconhecer automaticamente o projeto, criar uma nova app TV Web através da extensão e copiar os dois ficheiros; não substituir o projeto Tailscale antigo.
5. Instalar/abrir na TV e fotografar somente a tela do teste (sem identificadores privados).
6. Se a instalação falhar, guardar **mensagem exata de erro**, sem copiar ficheiros `.p12`.

## Interpretação

| Resultado | Significado |
|---|---|
| Instala e `Partner SSO: CHAMADA CONCLUÍDA` | A TV aceita e executa esta API Web Partner com este pacote. **Não prova que o serviço VPN nativo esteja disponível**. |
| Instala, mas `SecurityError` | Verificar se o pacote está assinado pelo perfil Partner e o privilégio está declarado. |
| `API não encontrada` | Plugin SSO pode não existir no modelo, independentemente do certificado; prova **inconclusiva**. |
| `.wgt` não instala | Verificar logs da ferramenta, assinatura, perfil, DUID e privilégios declarados. |

## Próxima etapa

Depois de validar a assinatura Partner, é necessário determinar se a TV **aceita componentes nativos** ou expõe outra interface autorizada para criar VPN global. Samsung declara em [FAQ de testes de aplicações TV](https://developer.samsung.com/smarttv/develop/faq/application-testing.html) que TVs aceitam `.wgt` e não `.tpk`, embora existam experiências de `.tpk` noutros firmwares; **não assumir** que a nossa Q60A Tizen 6 aceita pacotes nativos.

Nunca colocar certificados, passwords nem dados identificadores da TV neste repositório.

## Instalação automática no Windows (atualizado 2026-10-17)

O helper `scripts/build-partner-probe-windows.ps1` foi alterado para:
- inspeccionar dentro do `.wgt` final os três ficheiros essenciais `config.xml`, `author-signature.xml` e `signature1.xml`;
- instalar via **`tizen install -s SERIAL -n NOME.wgt -- PASTA`**, sintaxe oficial para Samsung TV, em lugar de `sdb install` (que no primeiro teste apenas fez push e terminou `closed`/código 1);
- deixar o erro de instalação detalhado visível para diagnóstico. Não modifica a configuração da TV além da tentativa de instalação.

Executar no Windows PowerShell (na mesma sessão em que a execução de scripts já estiver temporariamente permitida):

```powershell
$url = "https://raw.githubusercontent.com/hwiguel3/tailscale-tizen/tizen6-armv7-compat/scripts/build-partner-probe-windows.ps1"
$script = "$env:TEMP\build-partner-probe-windows.ps1"
Invoke-WebRequest $url -OutFile $script
& $script -Install
```

A **compilação Web anterior foi bem-sucedida**, mas a instalação não foi confirmada. Warnings sobre ausência de assinaturas no material de **entrada** são frequentemente informativos, mas o pacote de **saída** deve conter as assinaturas.

Códigos Samsung TV a distinguir: `205` sugere falha no certificado; `118` pode indicar pacote alterado ou inválido. Consultar: https://developer.samsung.com/smarttv/develop/faq/application-testing.html e https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/command-line-interface.html . Não assumir resolução até uma instalação efetiva.
