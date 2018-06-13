# Requisites: 
# A Data disk that has already been mounted or can be mounted as E:
# Script needs to be run as admin
# Will set a daily sync at 7:30am
# List of products to be ignored can be added to by adding a string that matches the name returned by Get-WsusProduct


#Create Data disk

if(!(Test-Path F:)){
Write-Verbose "Creating Data Drive F:"
Get-Disk |
Where partitionstyle -eq 'raw' |
Initialize-Disk -PartitionStyle MBR -PassThru |
New-Partition -DriveLetter 'F' -UseMaximumSize |
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
        New-Item -Path F: -Name WSUS -ItemType Directory
        CD "C:\Program Files\Update Services\Tools"
        .\wsusutil.exe postinstall CONTENT_DIR=F:\WSUS

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

        Write-Verbose "Set Default Automatic Approval Rule"

        #Create New Rule Object
        $newRule = $wsus.GetInstallApprovalRules() | Where {$_.Name -eq "Default Automatic Approval Rule"}

        ##Classifications
        #Get all Classifications for specific Classifications
        $updateClassifications = $wsus.GetUpdateClassifications() | Where {$_.Title -Match "Critical Updates|Definition Updates|Feature Packs|Security Updates|Service Packs|Update Rollups|Updates"}

        #Create collection for Categories
        $classificationCollection = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
        $classificationCollection.AddRange($updateClassifications )

        #Add the Classifications to the Rule
        $newRule.SetUpdateClassifications($classificationCollection)

        ##Target Groups
        #Get Target Groups required for Rule
        $targetGroups = $wsus.GetComputerTargetGroups() | Where {$_.Name -Match "All Computers"}

        #Create collection for TargetGroups
        $targetgroupCollection = New-Object Microsoft.UpdateServices.Administration.ComputerTargetGroupCollection
        $targetgroupCollection.AddRange($targetGroups)

        #Add the Target Groups to the Rule
        $newRule.SetComputerTargetGroups($targetgroupCollection)

        #Finalize the creation of the rule object
        $newRule.Enabled = $True
        $newRule.Save()

        #Run the rule
        $newRule.ApplyRule()

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
     
        #Approve legal agreements as required and approve each update for download
        Write-Verbose "Approving Legal agreements as required and approving Updates to install to All Computers group"
        
        $group = $wsus.GetComputerTargetGroups() | where {$_.Name -eq 'All Computers'}

        foreach($update in $updates | where-object {$_.IsDeclined -eq "False" }){
                if($update.RequiresLicenseAgreementAcceptance -eq "True"){
                    $update.AcceptLicenseAgreement()
                    }
                $update.Approve("Install", $group)
        }
}
