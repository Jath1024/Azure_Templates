
workflow Shutdown-Start-ARM-VMs-Parallel {
    sequence{
        try {
            $account = Connect-AzureRmAccount -Subscription 7cba3fdf-6b24-495e-9818-42cb0957b235
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
