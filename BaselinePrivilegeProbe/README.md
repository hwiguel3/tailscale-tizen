# Hugo Baseline Probe — controlo sem privilégio Partner

Uma app Web `.wgt` mínima para Samsung Tizen 6.0, assinada com o mesmo certificado Partner `SamsungTV_Hugo_2`, mas sem declarar `sso.partner` nem qualquer outro privilégio.

O anterior `Hugo Partner Probe` foi assinado e continha `author-signature.xml` / `signature1.xml`, mas o Tizen respondeu apenas `Failed to install Tizen application`. `install-permit` respondeu `Install Permitted`; isso não valida certificado nem privilégio.

## Teste de controlo

No Windows, após descarregar a última versão de `scripts/build-partner-probe-windows.ps1`, executar:

```powershell
& "$env:TEMP\partner-probe-baseline.ps1" -Variant Baseline -Install
```

O script cria um WGT com ID separado do probe anterior, usa a CLI Tizen e o certificado já registado e verifica as assinaturas antes de instalar.

## Interpretação

- **Baseline instala:** assinatura Partner e manifesto mínimo são aceites nesta TV. A falha anterior pode dever-se ao privilégio `sso.partner` ou a outra diferença do manifesto/código; **não prova VPN**.
- **Baseline falha:** problema pode ser certificado Partner associado a DUID, cadeia de confiança, manifesto ou ambiente. Próximo teste adequado: repetir baseline com o **perfil Public conhecido que já instalou apps**. Se esse funcionar e Partner não, focar a autorização do certificado Partner; não continuar a mexer no motor da VPN.
- **Primeiro assinou e depois install falhou:** recolher mensagem integral da ferramenta e, se disponível, inspeção de metadados do certificado (sem enviar .p12, passwords ou DUID).

Conserva o `PartnerPrivilegeProbe` original para comparação; nenhum dos testes modifica firmware ou liga VPN.

## Resultado do controlo Partner (17/10/2026)

O teste **sem privilégio** (`BaselinePrivilegeProbe`) assinado com `SamsungTV_Hugo_2` **também falhou** durante `tizen install`, após a compilação, as duas assinaturas e a transferência terem sido concluídas. A CLI só mostrou `Failed to install Tizen application` (código 1). No teste precedente, `install-permit` devolveu `Install Permitted`.

Isto afasta a hipótese de que a declaração do privilégio `sso.partner` seja **a única** causa. Não estabelece se a causa é o certificado, DUID, validade, conectividade externa da TV, pacote ou manifesto.

**Próximo teste A/B recomendado, sem alterar código:** repetir o mesmo `BaselinePrivilegeProbe` com perfil Public pré-existente `SamsungTV_Hugo`. O helper `scripts/build-partner-probe-windows.ps1` já aceita `-Variant Baseline -Profile SamsungTV_Hugo -Install`. Se a CLI não tiver este perfil registado, reutilizar os respetivos `.p12` locais sem expor passwords no GitHub; o script poderá pedir as passwords no PC.

- **Public instala, Partner falha:** comparar autorização DUID e cadeia de certificados Partner, e testar conectividade da TV à Internet para verificação da assinatura; não concluir que Partner é impossível.
- **Public e Partner falham:** comparar primeiro o manifesto e o processo de instalação com a aplicação Web que já foi instalada anteriormente via VS Code; não continuar a testar root ou VPN sem corrigir esta base.
- Ao comparar, idealmente usar o mesmo aparelho, o mesmo ID de pacote, os mesmos ficheiros e uma assinatura de cada vez.

**Não carregar certificados, passwords, ficheiros `profiles.xml` ou identificadores do dispositivo.**
