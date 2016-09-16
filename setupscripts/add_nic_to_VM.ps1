########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
# Copyright 2016 Cloudbase Solutions Srl
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABILITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################
param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    [Parameter(Mandatory=$true)]
    [string]$VSwitchName,
    [Parameter(Mandatory=$true)]
    [string]$NICName,
    [string]$MAC,
    [string]$IsLegacy,
    [string]$VLAN
)
Import-Module Hyper-V

Try{
    $cmd_args = @{
        VMName = $VMName
        SwitchName = $VSwitchName
        Name = $NICName
    }
    if ($MAC){
        $cmd_args.Add('StaticMacAddress', $MAC)
    }
    if ($IsLegacy){
        $cmd_args.Add('IsLegacy', $true)
    }
    Add-VMNetworkAdapter @cmd_args
    if ($VLAN){
        Set-VMNetworkAdapterVlan -VMName $VMName `
        -VMNetworkAdapterName $NICName -Access -VlanId $VLAN
    }
}
Catch [system.exception]{
    throw
}