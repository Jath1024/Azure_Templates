<# 
.SYNOPSIS 
    Creates scheduled tasks to start Virtual Machines. 
.DESCRIPTION 
    Creates scheduled tasks to start a single Virtual Machine or a set of Virtual Machines (using 
    wildcard pattern syntax for the Virtual Machine name). 
.EXAMPLE 
    Start-AzureVMsOnSchedule.ps1 -ServiceName "MyServiceName" -VMName "testmachine1" ` 
        -TaskName "Start Test Machine 1" -At 8AM 
     
    Start-AzureVMsOnSchedule.ps1 -ServiceName "MyServiceName" -VMName "test*" ` 
        -TaskName "Start All Test Machines" -At 8:15AM 
#> 
 
 
param( 
    # The name of the VM(s) to start on schedule.  Can be wildcard pattern. 
    [Parameter(Mandatory = $true)]  
    [string]$VMName, 
 
 
    # The service name that $VMName belongs to. 
    [Parameter(Mandatory = $true)]  
    [string]$ServiceName, 
 
 
    # The name of the scheduled task. 
    [Parameter(Mandatory = $true)]  
    [string]$TaskName, 
 
 
    # The name of the "Stop" scheduled tasks. 
    [Parameter(Mandatory = $true)]  
    [DateTime]$At) 
 
 
# The script has been tested on Powershell 3.0 
Set-StrictMode -Version 3 
 
 
# Following modifies the Write-Verbose behavior to turn the messages on globally for this session 
$VerbosePreference = "Continue" 
 
 
# Check if Windows Azure Powershell is avaiable 
if ((Get-Module -ListAvailable Azure) -eq $null) 
{ 
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
} 
 
 
# Define a scheduled task to start the VM(s) on a schedule. 
$startAzureVM = "Start-AzureVM -Name " + $VMName + " -ServiceName " + $ServiceName + " -Verbose" 
$startTaskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At $At 
$startTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $startAzureVM 
$startTaskSettingsSet = New-ScheduledTaskSettingsSet  -AllowStartIfOnBatteries  
 
$startScheduledTask = New-ScheduledTask -Action $startTaskAction -Trigger $startTaskTrigger -Settings $startTaskSettingsSet 
 
 
# Register the scheduled tasks to start and stop the VM(s). 
Register-ScheduledTask -TaskName $TaskName -InputObject $startScheduledTask 
 

###############################################################################################################################

<# 
.SYNOPSIS 
    A powershell workflow to start Virtual Machines in parallel. 
.DESCRIPTION 
    The runbook will send the start command to a set of Virtual Machines in parallel. The runbook uses two tags
    to identify the Tier of the VM and the start schedule.
    The runbook must be created as a Powershell Workflow in Azure Automation.     
    The runbook schedule should be set to execute the runbook depending on the daily start requirement of the VMs.
    For instance, if VMs tagged as Daily should be turned on a 7am Mon-Fri, the runbook should execute sometime before 7am
    Mon-Fri to allow time for the VMs to start.
    The runbook will start all VMs within a subscription. It can be easily edited to apply to a specific resource group.
    The runbook is intended to be used in conjunction with the //TODO// to power down VMs on a schedule.

.EXAMPLE 
    Runbook scheduled for 6:30AM Monday to Friday.

    ForEach -Parallel ($VM in $VMs) {
        if(($VM.Tags.Keys -eq "AutoShutdownSchedule") -and ($vm.Tags.Values -eq "DailyOnOff")){
            if(($vm.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq $($FirstTier))){
                Write-Output "Starting First Tier VMs"
                Write-Output "Starting: $($VM.Name)"
                Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
            }
        }
    }

    ForEach -Parallel ($VM in $VMs) {
        if(($VM.Tags.Keys -eq "AutoShutdownSchedule") -and ($vm.Tags.Values -eq "DailyOnOff")){
            if(($vm.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq $($SecondTier))){
                Write-Output "Starting Second Tier VMs"
                Write-Output "Starting: $($VM.Name)"
                Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
            }
        }
    }

    ForEach -Parallel ($VM in $VMs) {
        if(($VM.Tags.Keys -eq "AutoShutdownSchedule") -and ($vm.Tags.Values -eq "DailyOnOff")){
            if(($vm.Tags.Keys -eq "Tier") -and ($vm.Tags.Values -eq $($ThirdTier))){
                Write-Output "Starting Thurd Tier VMs"
                Write-Output "Starting: $($VM.Name)"
                Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
            }
        }
    }
#> 

param( 
    #Schedule Tag Key
    [Parameter(Mandatory = $true)]
    [String]$ScheduleTagKey,

    #Schedule Tag Value
    [Parameter(Mandatory = $true)]
    [String]$ScheduleTagValue,

    #Tier Tag Key
    [Parameter(Mandatory = $true)]
    [String]$TierTagKey,

    #The Tier Tag Value that identifies the group of VMs that should be powered down first
    [Parameter(Mandatory = $true)]
    [String]$FirstTier,

    #The Tier Tag Value that identifies the group of VMs that should be powered down second
    [Parameter(Mandatory = $true)]
    [String]$SecondTier,

    #The Tier Tag Value that identifies the group of VMs that should be powered down third
    [Parameter(Mandatory = $true)]
    [String]$ThirdTier) 

# The script has been tested
Set-StrictMode -Version 5

workflow Startup-ARM-VMs-Parallel-Runbook
{
    sequence{
        try {
            $Conn = Get-AutomationConnection -Name AzureRunAsConnection
            $account = Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
        }
        catch {
            if(!$account){
                $ErrorMessage = "Account not found."
                throw $ErrorMessage
            }
        }

        $VMs = Get-AzureRMVm
    
        ForEach -Parallel ($VM in $VMs) {
            if(($VM.Tags.Keys -eq $($ScheduleTagKey)) -and ($vm.Tags.Values -eq $($ScheduleTagValue))){
                if(($vm.Tags.Keys -eq $TierTagKey) -and ($vm.Tags.Values -eq $($FirstTier))){
                    Write-Output "Starting First Tier VMs"
                    Write-Output "Starting: $($VM.Name)"
                    Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                }
            }
        }

        ForEach -Parallel ($VM in $VMs) {
            if(($VM.Tags.Keys -eq $($ScheduleTagKey)) -and ($vm.Tags.Values -eq $($ScheduleTagValue))){
                if(($vm.Tags.Keys -eq $TierTagKey) -and ($vm.Tags.Values -eq $($SecondTier))){
                    Write-Output "Starting Second Tier VMs"
                    Write-Output "Starting: $($VM.Name)"
                    Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                }
            }
        }

        ForEach -Parallel ($VM in $VMs) {
            if(($VM.Tags.Keys -eq $($ScheduleTagKey)) -and ($vm.Tags.Values -eq $ScheduleTagValue)){
                if(($vm.Tags.Keys -eq $TierTagKey) -and ($vm.Tags.Values -eq $($ThirdTier))){
                    Write-Output "Starting Thurd Tier VMs"
                    Write-Output "Starting: $($VM.Name)"
                    Start-AzureRMVM -DefaultProfile $account -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                }
            }
        }

    }
}
