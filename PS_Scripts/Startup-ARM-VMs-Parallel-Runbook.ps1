workflow Startup-ARM-VMs-Parallel-Runbook
{
    sequence{
        try {
            $Conn = Get-AutomationConnection -Name AzureRunAsConnection
            $account = Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
        }
        catch {
            if(!$account){
                $ErrorMessage = "Connection $account not found."
                throw $ErrorMessage
            }
        }

        $VMs = Get-AzureRMVm
    
        ForEach -Parallel ($VM in $VMs) {
            if(($VM.Tags.Keys -eq "AutoShutdownSchedule") -and ($vm.Tags.Values -eq "DailyOff")){
                if(($vm.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq "0")){
                    Write-Output "Starting Tier 0 VMs"
                    Write-Output "Starting: $($VM.Name)"
                    Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                }
            }
        }

        ForEach -Parallel ($VM in $VMs) {
            if(($VM.Tags.Keys -eq "AutoShutdownSchedule") -and ($vm.Tags.Values -eq "DailyOff")){
                if(($vm.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq "1")){
                    Write-Output "Starting Tier 1 VMs"
                    Write-Output "Starting: $($VM.Name)"
                    Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                }
            }
        }

        ForEach -Parallel ($VM in $VMs) {
            if(($VM.Tags.Keys -eq "AutoShutdownSchedule") -and ($vm.Tags.Values -eq "DailyOff")){
                if(($vm.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq "2")){
                    Write-Output "Starting Tier 2 VMs"
                    Write-Output "Starting: $($VM.Name)"
                    Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                }
            }
        }

    }
}
