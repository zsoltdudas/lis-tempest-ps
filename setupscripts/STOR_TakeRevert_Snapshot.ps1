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

param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”), [string] $snapshotName=$(throw “No input”))

#
# Take a snapshot then restore the VM to the snapshot
#
"Info : Taking Snapshot operation on VM"

Checkpoint-VM -Name $vmName -SnapshotName $snapshotName -ComputerName $hvServer
if (-not $?)
{
    Write-Output "Error: Taking snapshot" | Out-File -Append $summaryLog
    return -1
}

"Info : Restoring Snapshot operation on VM"
Restore-VMSnapshot -VMName $vmName -Name $snapshotName -ComputerName $hvServer -Confirm:$false
if (-not $?)
{
    Write-Output "Error: Restoring snapshot" | Out-File -Append $summaryLog
    $error[0].Exception.Message
    return -1
}
