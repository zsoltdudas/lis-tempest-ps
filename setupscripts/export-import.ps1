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

param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”))

$retVal = $False
$testCaseTimeout = 600

#####################################################################
#
# Check VM current state
#
#####################################################################
function CheckCurrentStateFor([String] $vmName, $newState)
{
    $stateChanged = $False
    $vm = Get-VM -Name $vmName -ComputerName $hvServer

    if ($($vm.State) -eq $newState) {
        $stateChanged = $True
    }

    return $stateChanged
}

#####################################################################
#
# Main script body
#
#####################################################################

# Check that the VM is present on the server and it is in running state.
#
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm) {
    "Error: Cannot find VM ${vmName} on server ${hvServer}"
    Write-Output "VM ${vmName} not found"
    exit -1
}


Write-Output "VM ${vmName} is present on server and running"

#
# Stop the VM to export it.
#
while ($testCaseTimeout -gt 0) {
    Stop-VM -Name $vmName -ComputerName $hvServer -Force -Verbose

    if ( (CheckCurrentStateFor $vmName ("Off"))) {
        break
    }

    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}

if ($testCaseTimeout -eq 0) {
    Write-Output "Error: Test case timed out waiting for VM to stop"
    exit -1
}

Write-Output "VM ${vmName} has stopped successfully"

#
# Create a Snapshot before exporting the VM
#
Checkpoint-VM -Name $vmName -ComputerName $hvServer -SnapshotName "TestExport" -Confirm:$False
if ($? -ne "True") {
    Write-Output "Error while creating the snapshot"
    exit -1
}

Write-Output "Successfully created a new snapshot before exporting the VM"


$exportPath = (Get-VMHost).VirtualMachinePath + "\ExportTest\"

$vmPath = $exportPath + $vmName +"\"

#
# Delete existing export, if any.
#
Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue

#
# Export the VM.
#
Export-VM -Name $vmName -ComputerName $hvServer -Path $exportPath -Confirm:$False -Verbose
if ($? -ne "True") {
    Write-Output "Error while exporting the VM"
    exit -1
}

Write-Output "VM ${vmName} exported successfully"

#
# Before importing the VM from exported folder, Delete the created snapshot from the orignal VM.
#
Get-VMSnapshot -VMName $vmName -ComputerName $hvServer -Name "TestExport" | Remove-VMSnapshot -Confirm:$False

#
# Save the GUID of exported VM.
#
$ExportedVM = Get-VM -Name $vmName -ComputerName $hvServer
$ExportedVMID = $ExportedVM.VMId

#
# Import back the above exported VM.
#
$vmConfig = Get-Item "$vmPath\Virtual Machines\*.xml"

Write-Output $vmConfig.fullname

Import-VM -Path $vmConfig -ComputerName $hvServer -Copy "${vmPath}\Virtual Hard Disks" -Verbose -Confirm:$False   -GenerateNewId
if ($? -ne "True") {
    Write-Output "Error while importing the VM"
    exit -1
}

Write-Output "VM ${vmName} has imported back successfully"

#
# Check that the imported VM has a snapshot 'TestExport', apply the snapshot and start the VM.
#
$VMs = Get-VM -Name $vmName -ComputerName $hvServer

$newName = "Imported_" + $vmName

foreach ($Vm in $VMs) {
   if ($ExportedVMID -ne $($Vm.VMId)) {
       $ImportedVM = $Vm.VMId
       Get-VM -Id $Vm.VMId | Rename-VM -NewName $newName
       break
   }
}

Get-VMSnapshot -VMName $newName -ComputerName $hvServer -Name "TestExport" | Restore-VMSnapshot -Confirm:$False -Verbose
if ($? -ne "True") {
    Write-Output "Error while applying the snapshot to imported VM $ImportedVM"
    exit -1
}

#
# Verify that the imported VM has started successfully
#
Write-Host "Starting the VM $newName and waiting for the heartbeat..."

if ((Get-VM -ComputerName $hvServer -Name $newName).State -eq "Off") {
    Start-VM -ComputerName $hvServer -Name $newName
}

While ((Get-VM -ComputerName $hvServer -Name $newName).State -eq "On") {
    Write-Host "." -NoNewLine
    Start-Sleep -Seconds 5
}

do {
    Start-Sleep -Seconds 5
} until ((Get-VMIntegrationService $newName | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")

Write-Output "Imported VM ${newName} has a snapshot TestExport, applied the snapshot and VM started successfully"


Stop-VM -Name $newName -ComputerName $hvServer -Force -Verbose
if ($? -ne "True") {
    Write-Output "Error while stopping the VM"
    exit -1
}

Write-Output "VM exported with a new snapshot and imported back successfully"

#
# Cleanup - stop the imported VM, remove it and delete the export folder.
#
Remove-VM -Name $newName -ComputerName $hvServer -Force -Verbose
if ($? -ne "True") {
    Write-Output "Error while removing the Imported VM"
    exit -1
}
else {
    Write-Output "Imported VM Removed, test completed"
}

Remove-Item -Path "${vmPath}" -Recurse -Force
if ($? -ne "True") {
    Write-Output "Error while deleting the export folder trying again"
    del -Recurse -Path "${vmPath}" -Force
}

