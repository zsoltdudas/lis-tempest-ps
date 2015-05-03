# Copyright 2014 Cloudbase Solutions Srl
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

param([string] $vmName, [string] $hvServer, [string] $targetDrive)

# Check input arguments
if ($vmName -eq $null)
{
    throw "ERROR: VM name is null"
}

if ($hvServer -eq $null)
{
    throw "ERROR: hvServer name is null"
}

if ($targetDrive -eq $null)
{
    throw "ERROR: Backup target drive is not specified."
}

# Check if the Vm VHD in not on the same drive as the backup destination 
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm)
{
    throw "Error: VM '${vmName}' does not exist"
}
 
foreach ($drive in $vm.HardDrives)
{
    if ( $drive.Path.StartsWith("${targetDrive}"))
    {
        throw "Error: Backup partition '${targetDrive}' is same as partition hosting the VMs disk"
    }
}

# Install the Windows Backup feature
Write-Output "Checking if the Windows Server Backup feature is installed..."
try { Add-WindowsFeature -Name Windows-Server-Backup -IncludeAllSubFeature:$true -Restart:$false }
Catch { Write-Output "Windows Server Backup feature is already installed, no actions required."}

# Remove any old backups
Write-Output "Removing old backups"
try { Remove-WBBackupSet -Force -WarningAction SilentlyContinue }
Catch { Write-Output "No existing backup's to remove"}

# Remove Existing Backup Policy
try { Remove-WBPolicy -all -force }
Catch { Write-Output "`nNo existing backup policy to remove"}

# Set up a new Backup Policy
$policy = New-WBPolicy

# Set the backup backup location
$backupLocation = New-WBBackupTarget -VolumePath $targetDrive

# Define VSS WBBackup type
Set-WBVssBackupOptions -Policy $policy -VssCopyBackup

# Add the Virtual machines to the list
$VM = Get-WBVirtualMachine | where vmname -like $vmName
Add-WBVirtualMachine -Policy $policy -VirtualMachine $VM
Add-WBBackupTarget -Policy $policy -Target $backupLocation

# Display the Backup policy
Write-Output "`nBackup policy is: `n$policy"

$Date = Get-Date
# Start the backup
Write-Output "`nBacking to $targetDrive"
Start-WBBackup -Policy $policy
# Review the results            
$BackupTime = (New-Timespan -Start (Get-WBJob -Previous 1).StartTime -End (Get-WBJob -Previous 1).EndTime).Minutes
Write-Output "`nBackup duration: $BackupTime minutes"           

$sts=Get-WBJob -Previous 1
if ($sts.JobState -ne "Completed")
{
    throw "ERROR: VSS WBBackup failed"
}


Write-Output "`nBackup success!`n"
# Let's wait a few Seconds
Start-Sleep -Seconds 3

Write-Output "INFO: Going through Event Logs for Warninig ID 10107"
# Now Check if Warning related Error is present in Event Log ? Backup should fail .
$EventLog = Get-WinEvent -ProviderName Microsoft-Windows-Hyper-V-VMMS | where-object {  $_.TimeCreated -gt $Date}

$retVal = $false
# Event ID 10107 is what we looking here, it will be always be 10107.
foreach ($event in $EventLog)
   {
       if ($event.Id -eq 10150)
       {           
           $retVal = $True
           Write-Output "INFO : " + $event.Message
           Write-Output "INFO :VSS Backup Error in Event Log : Success"
                      
       }              
   }

if ($retVal -eq $false)
{
     Write-Error "INFO :VSS Backup Error not in Event Log"   
     exit -1
}