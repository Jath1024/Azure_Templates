
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
New-Item -Path C: -Name WSUS -ItemType Directory
CD "C:\Program Files\Update Services\Tools"
.\wsusutil.exe postinstall CONTENT_DIR=C:\WSUS
 
Write-Verbose "Get WSUS Server Object" -Verbose
$wsus = Get-WSUSServer
 
Write-Verbose "Connect to WSUS server configuration" -Verbose
$wsusConfig = $wsus.GetConfiguration()
 
Write-Verbose "Set to download updates from Microsoft Updates" -Verbose
Set-WsusServerSynchronization -SyncFromMU
 
Write-Verbose "Set Update Languages to English and save configuration settings" -Verbose
$wsusConfig.AllUpdateLanguagesEnabled = $false           
$wsusConfig.SetEnabledUpdateLanguages("en")           
$wsusConfig.Save()
 
Write-Verbose "Get WSUS Subscription and perform initial synchronization to get latest categories" -Verbose
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
 
 While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
 Write-Host "." -NoNewline
 Start-Sleep -Seconds 5
 }
 
Write-Verbose "Sync is Done" -Verbose

Write-Verbose "Enable Products" -Verbose
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -ne $null } | Set-WsusProduct

Write-Verbose "Disable Products" -Verbose
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Antigen" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Bing" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Biztalk" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Developer tools" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Exchange" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Expression" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Microsoft Dynamics" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Microsoft Lync Server" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office Live" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Skype for Business" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Skype" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Live" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Vista" } | Set-WsusProduct -Disable
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows XP" } | Set-WsusProduct -Disable

$allproducts = Get-WsusProduct
$disabledprodlist = @()
foreach($product in $allproducts){
    $disabledprodlist += $product
    }

$disabledprodlist = @("office", "windows", "antigen", "bing", "biztalk", "developer tools", "exchange", "expression", "microsoft dynamics", "Microsoft lync server", "office live", "skype for business", "skype", "windows live", "windows vista", "windows xp")

foreach($product in $DisabledProds)
    {
        Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "$product" } | Set-WsusProduct -Disable
    }


#Write-Verbose "Enable Products" -Verbose
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2016" } | Set-WsusProduct
 
#Write-Verbose "Disable Language Packs" -Verbose
#Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Language Packs" } | Set-WsusProduct -Disable
 
Write-Verbose "Configure the Classifications" -Verbose
 
 Get-WsusClassification | Where-Object {
 $_.Classification.Title -in (
 'Critical Updates',
 'Definition Updates',
 'Feature Packs',
 'Security Updates',
 'Service Packs',
 'Update Rollups',
 'Updates')
 } | Set-WsusClassification
 
Write-Verbose "Configure Synchronizations" -Verbose
$subscription.SynchronizeAutomatically=$true
 
Write-Verbose "Set synchronization scheduled for midnight each night" -Verbose
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours -2)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()
 
Write-Verbose "Kick Off Synchronization" -Verbose
$subscription.StartSynchronization()
 
Write-Verbose "Monitor Progress of Synchronisation" -Verbose
 
Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
 while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
 #$subscription.GetSynchronizationProgress().ProcessedItems * 100/($subscription.GetSynchronizationProgress().TotalItems)
 Start-Sleep -Seconds 5
 }