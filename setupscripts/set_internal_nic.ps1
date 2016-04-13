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

param([string] $vmName=$(throw "No input"), [string] $hvServer=$(throw "No input"), [string] $mac=$(throw "No input"), [string] $gateway=$(throw "No input"))

$ERROR.Clear()
$vswitch = Get-VMNetworkAdapter -VMName $vmName | where {$_.MacAddress -like $mac}
if(!$vswitch)
{
    Write-Output "ERROR: Couldn't find any vswitch with mac ${mac}"
    exit -1
}

$vswitch_name = $vswitch.SwitchName
$internal = Get-NetAdapter | where { $_.Name.Contains($vswitch_name)}
if($internal -is [system.array])
{
    Write-Output "ERROR: ${vswitch_name} returns array."
    exit -1

}

if(!$internal)
{
    Write-Output "ERROR: Couldn't find any network adapter  with name ${vswitch_name}"
    exit -1
}
if($internal.Name.Contains('external'))
{
    Write-Output "ERROR: Net adapter might be external! Vswitch name: ${vswitch_name}"
    exit -1
}
$internal | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
$internal | New-NetIPAddress -AddressFamily IPv4 -IPAddress $gateway -PrefixLength 24
if ($ERROR.Count -gt 0)
{
    Write-Output "ERROR: "
    $ERROR[0].Exception
    exit -1
}
sleep 10