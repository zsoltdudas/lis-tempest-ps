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

# Start the Restore
Write-Output "`nNow let's do restore ...`n"

# Get BackupSet
$BackupSet=Get-WBBackupSet -WarningAction SilentlyContinue
if ($BackupSet -eq $null)
{
    throw "ERROR: No existing backups found!"
}

# Start Restore
Start-WBHyperVRecovery -BackupSet $BackupSet -VMInBackup $BackupSet.Application[0].Component[0] -Force -WarningAction SilentlyContinue
$sts=Get-WBJob -Previous 1
if ($sts.JobState -ne "Completed")
{
    throw "ERROR: Restore failed!"
}

# Review the results  
$RestoreTime = (New-Timespan -Start (Get-WBJob -Previous 1).StartTime -End (Get-WBJob -Previous 1).EndTime).Minutes
Write-Output "`nRestore duration: $RestoreTime minutes"

# Make sure VM exsist after VSS backup/restore Operation 
$vm = Get-VM -Name $vmName -ComputerName $hvServer
    if (-not $vm)
    {
        throw "ERROR: VM ${vmName} does not exist after restore"
    }

Write-Output "`nRestore success!"

# After Backup Restore VM must be off make sure that.
if ( $vm.state -ne "Off" )  
{
    throw "ERROR: VM is not in OFF state, current state is " + $vm.state 
}

# Now Start the VM 
Start-VM -Name $vmName -ComputerName $hvServer
