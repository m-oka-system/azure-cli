## 自己証明書を作成

```
# 保護するドメイン名を指定
$domain = ""

# 「個人」の証明書ストアに証明書を作成
$my = "cert:\CurrentUser\My"
$cert = New-SelfSignedCertificate -DnsName $domain -CertStoreLocation $my

# cer (自己証明書)をエクスポート
$cerfile  = "c:\$($domain).cer"
Export-Certificate -Cert $cert -FilePath $cerfile

# 「信頼されたルート証明機関」に cer を登録
$root = "cert:\CurrentUser\Root"
Import-Certificate -FilePath $cerfile -CertStoreLocation $root

# pfx (SSL証明書)をエクスポート
$pfxfile  = "c:\$($domain).pfx"
$password = "password"
$sspwd = ConvertTo-SecureString -String $password -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $pfxfile -Password $sspwd
```

```
# デフォルトポリシーを取得
az keyvault certificate get-default-policy > policy.json

# 自己証明書をKey Vaultに作成
az keyvault certificate create --name mycert --vault-name e-paas-vault --policy @policy.json

# 証明書をダウンロード
az keyvault certificate download --name mycert --vault-name e-paas-vault --encoding PEM --file example.crt
az keyvault certificate download --name e-paas-selfcert --vault-name e-paas-vault --encoding PEM --file e-paas-self.crt
```
