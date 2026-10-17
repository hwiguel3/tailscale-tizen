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
