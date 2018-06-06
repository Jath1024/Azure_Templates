# Requisites: 
# A Data disk that has already been mounted or can be mounted as E:
# Script needs to be run as admin
# Will set a daily sync at 7:30am
# List of products to be ignored can be added to by adding a string that matches the name returned by Get-WsusProduct


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

if($wsusstateinstalled -eq 'Installed'){
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

    
    foreach($product in $allproducts)
    {
    $disabledprodlist = @("office", 
                          "antigen", 
                          "bing", 
                          "biztalk", 
                          "developer tools", 
                          "exchange", 
                          "expression", 
                          "microsoft dynamics", 
                          "Microsoft lync server", 
                          "office live", 
                          "skype for business", 
                          "skype", 
                          "windows live", 
                          "windows vista", 
                          "windows xp")
                                
    foreach($disprod in $disabledprodlist)
        {
            if($product.product.title -match $disprod) <#This loop checks to see if the product matches the unwanted product list above and sets a flag of 1 if there is a match#>
                {
                    Write-Output "Match" $product.Product.Title
                    $disableproductflag = 1
                    Write-Output $disableproductflag
                    BREAK <#set disable product flag to 1 and break out of foreach loop#>
                    }
            ElseIf ($product.product.id -eq "56309036-4c77-4dd9-951a-99ee9c246a94") {
                    Write-Output "Match" $product.Product.Title
                    $disableproductflag = 1
                    BREAK <#This is a product that enables all products - so it must be ignored - disabled flag is set to 1#>
                    } 
            Else 
                {
                    Write-OUtput "no match" $product.Product.Title
                    $disableproductflag = 0 <#Product is wanted - setting productflag to 0 and continue in loop to check for potential disabled product match#>
                    Write-Output $disableproductflag
                    }
        }
        if($disableproductflag -eq 0)
            { 
                write-output "enabling" $product.product.title
                Get-wsusserver | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match $product.product.title } | Set-WsusProduct
                #write-output "sleep for 10 seconds"
                #Start-Sleep -Seconds 10
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
