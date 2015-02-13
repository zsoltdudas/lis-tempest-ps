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

$ERROR.Clear()

Set-VM -Name $vmName -ComputerName $hvServer -ProcessorCount 1
$vmSwitch = Get-VM -Name $vmName | Get-VMNetworkAdapter
$vlan = Get-VMNetworkAdapterVlan -VMName $vmName -VMNetworkAdapterName $vmSwitch.Name
$a=Add-VMNetworkAdapter -VMName $vmName -SwitchName $vmSwitch.SwitchName -IsLegacy:$True -ComputerName $hvServer -Passthru
Set-VMNetworkAdapterVlan -VMName $vmName -VMNetworkAdapterName $a.Name -Access:$True -VlanId $vlan.AccessVlanId

if ($ERROR.Count -gt 0)
{
    Write-Output "ERROR: "
    $ERROR[0].Exception
    exit -1
}