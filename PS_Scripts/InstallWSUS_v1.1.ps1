#Create Data disk

if(!(Test-Path E:)){
Write-Verbose "Creating Data Drive E:"
Get-Disk |
Where partitionstyle -eq 'raw' |
Initialize-Disk -PartitionStyle MBR -PassThru |
New-Partition -DriveLetter 'E' -UseMaximumSize |
Format-Volume -FileSystem NTFS -NewFileSystemLabel "dataDisk" -Confirm:$false
}

#Check if WSUS is enabled
Write-Verbose "Checking for WSUS Service"
$wsusstate = Get-WindowsFeature -Name  UpdateServices
$wsusstateinstalled = $wsusstate.InstallState

if($wsusstateinstalled='Installed'){
        exit
    }

else{

    #Install WSUS 
    Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
    New-Item -Path E: -Name WSUS -ItemType Directory
    CD "C:\Program Files\Update Services\Tools"
    .\wsusutil.exe postinstall CONTENT_DIR=E:\WSUS
 
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
    $allproducts = Get-WsusProduct

    $disabledprodlist = @("office", "windows", "antigen", "bing", "biztalk", "developer tools", "exchange", "expression", "microsoft dynamics", "Microsoft lync server", "office live", "Office Live Add-in", "skype for business", "skype", "windows live", "windows vista", "windows xp", "works")


    foreach($product in $allproducts)
        {
        foreach($disprod in $disabledprodlist)
            {
                if($product.product.title -match $disprod)
                    {
                        $disableproductflag = 1
                        BREAK <#If product should not be enabled break out of foreach loop and move to next product#>
                        }
                Else 
                    {
                        $disableproductflag = 0
                        }
                if($disableproductflag = 0)
                        {
                        Get-wsusserver | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match $product.product.title } | Set-WsusProduct
                        }
            }
        }
 
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
    $subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 7  -Minutes 30)
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
}
