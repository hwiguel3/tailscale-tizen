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

## Diagnóstico de assinatura ausente (17/10/2026)

Foi confirmado no teste real: `tizen package` concluiu com exit code 0, mas o WGT não continha `author-signature.xml`. Isto é **erro de assinatura/integração do perfil**, e não erro de instalação por falta de permissões Partner.

O script foi atualizado para confirmar **antes de compilar** que a CLI encontra `SamsungTV_Hugo_2` através de `tizen security-profiles list`. Se não encontra, procura `profiles.xml` nas localizações habituais. Quando encontra um perfil único, configura `default.profiles.path` para a CLI, depois valida novamente. Trata-se de alteração **persistente na configuração de caminho da CLI**, sem mudar os certificados. Se não encontrar, pára com diagnóstico seguro em vez de compilar um pacote inútil. Também valida a existência dos ficheiros de assinatura no pacote.

Se o `profiles.xml` estiver noutro local, indicar ao script (sem enviar ficheiros sensíveis):

```powershell
& "$env:TEMP\build-partner-probe-windows.ps1" -ProfilesXml "C:\PASTA\profiles.xml" -Install
```

Para verificar a CLI em modo só de leitura:

```powershell
& "C:\tizen-studio\tools\ide\bin\tizen.bat" security-profiles list
& "C:\tizen-studio\tools\ide\bin\tizen.bat" cli-config -l | Select-String "profiles.path"
```

**Nunca partilhar `profiles.xml`, `.p12` nem palavras-passe.** Ocultar caminhos pessoais se necessário.

## Resultado real: CLI sem perfil da extensão VS Code (17/10/2026, 15:01)

A fotografia do PowerShell mostrou `O perfil SamsungTV_Hugo_2 existe no Certificate Manager mas NAO esta acessivel a esta CLI Tizen` e não encontrou `profiles.xml` nas pastas habituais. Isto é **diferença entre Certificate Manager da extensão VS Code e a CLI clássica**; não é prova de problema do certificado.

O helper Windows foi novamente atualizado para:
1. procurar um `profiles.xml` reutilizável;
2. se não existir, localizar **ambos os .p12** do perfil já criado em `%USERPROFILE%\SamsungCertificate\SamsungTV_Hugo_2\` ou no keystore do Tizen Studio;
3. pedir **apenas no PC** passwords do autor e distribuidor através de `Read-Host -AsSecureString`, com entrada oculta;
4. executar `tizen security-profiles add -n ... -a ... -p ... -d ... -dp ...` para **registar** o perfil na CLI, sem recriar certificados;
5. verificar de novo `tizen security-profiles list` e validar assinaturas `author-signature.xml`/`signature1.xml` antes de qualquer instalação.

O comando oficial CLI usa `-dp` para password do distribuidor; a ferramenta `tz` diferente usa `-P`. Referência: https://github.com/Samsung/tizen-docs/blob/master/docs/sdk-tools/baseline-sdk/common-tools/command-line-interface.md

Segurança: a interface CLI clássica recebe passwords como argumentos de processo no Windows, que poderão ficar temporariamente visíveis a ferramentas locais de monitorização. Não enviar passwords para o ChatGPT/GitHub nem guardar logs dessa execução. Não executar o script em PCs de terceiros ou sujeitos a monitorização não confiável.

Se a nova tentativa não encontrar os .p12, parar e localizar a pasta através do Certificate Manager, sem repetir compilação.
