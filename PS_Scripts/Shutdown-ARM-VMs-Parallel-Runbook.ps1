workflow Shutdown-ARM-VMs-Parallel-Runbook
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
            if(($VM.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq "0" -or $vm.Tags.Values -eq "1")){
                Write-Output "Shutting down: $($VM.Name)"
                Stop-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Force
            }
        }
    }
}
