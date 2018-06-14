#Modified April:2017
#am@rober.to
#original on : https://blogs.msdn.microsoft.com/appserviceteam/2017/02/24/creating-a-local-pfx-copy-of-app-service-certificate/
 
#add the 4 values below:
 
$appServiceCertificateName = "<Name for the Certificate Service>"
$resourceGroupName = "<Name of the Resource Group>"
$azureLoginEmailId = "<Your login ID goes here username@domain.com"
$subscriptionId = "<The Subscription ID>"
 
Login-AzureRmAccount -SubscriptionId $subscriptionId
 
Set-AzureRmContext -SubscriptionId $subscriptionId
 
$ascResource = Get-AzureRmResource -ResourceName $appServiceCertificateName -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.CertificateRegistration/certificateOrders" -ApiVersion "2015-08-01"
 
#last, add the 2 values below
$keyVaultId = "<Name of the Key Vault>"
$keyVaultSecretName = "<Secret of they KeyVault>"
 
#########################No more adding of variables further##########
 
$certificateProperties=Get-Member -InputObject $ascResource.Properties.certificates[0] -MemberType NoteProperty
$certificateName = $certificateProperties[0].Name
$keyVaultId = $ascResource.Properties.certificates[0].$certificateName.KeyVaultId
$keyVaultSecretName = $ascResource.Properties.certificates[0].$certificateName.KeyVaultSecretName
 
$keyVaultIdParts = $keyVaultId.Split("/")
$keyVaultName = $keyVaultIdParts[$keyVaultIdParts.Length - 1]
$keyVaultResourceGroupName = $keyVaultIdParts[$keyVaultIdParts.Length - 5]
 
Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $keyVaultResourceGroupName -VaultName $keyVaultName -UserPrincipalName $azureLoginEmailId -PermissionsToSecrets get
$secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName
$pfxCertObject=New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @([Convert]::FromBase64String($secret.SecretValueText),"", [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
$pfxPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 50 | % {[char]$_})
 
$currentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
[io.file]::WriteAllBytes(".\appservicecertificate.pfx", $pfxCertObject.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $pfxPassword))
Write-Host "Created an App Service Certificate copy at: $currentDirectory\appservicecertificate.pfx"
Write-Warning "For security reasons, do not store the PFX password. Use it directly from the console as required."
Write-Host "PFX password: $pfxPassword"
 
#END of script