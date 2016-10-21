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
    [Parameter(ParameterSetName='ext')]
    [string]$externalSwitch,
    [Parameter(ParameterSetName='ext')]
    [string]$netInterface,
    [string]$privateSwitch,
    [string]$internalSwitch,
    [string]$VLAN
    )
Import-Module Hyper-V

Try{
    if ($externalSwitch) {
        $ethernet = Get-NetAdapter -InterfaceDescription "$netInterface"
        write-output "Adding vSwitch $externalSwitch on $($ethernet.Name)"
        $cmd_args_ext = @{
            Name = $externalSwitch
            NetAdapterName = $ethernet.Name
            AllowManagementOS = $true
            Notes = "External switch by SetupVSwitch script"
        }
        New-VMSwitch @cmd_args_ext
        if ($VLAN){
            Get-VMNetworkAdapter -SwitchName $cmd_args_ext.Name `
            -ManagementOS | Set-VMNetworkAdapterVlan -Access -VlanId $VLAN
        }
    }
    if ($privateSwitch) {
        $cmd_args_priv = @{
            Name = $privateSwitch
            SwitchType = "Private"
            Notes = "Private switch by SetupVSwitch script"
        }
        New-VMSwitch @cmd_args_priv
        if ($VLAN){
            Write-Debug "Vlan cannot be set for private networks"
        }
    }
    if ($internalSwitch) {
        $cmd_args_int = @{
            Name = $internalSwitch
            SwitchType = "Internal"
            Notes = "Internal switch by SetupVSwitch script"
        }
        New-VMSwitch @cmd_args_int
        if ($VLAN){
            Get-VMNetworkAdapter -SwitchName $cmd_args_int.Name `
            -ManagementOS | Set-VMNetworkAdapterVlan -Access -VlanId $VLAN
        }
    }
}
Catch [system.exception]{
    throw
}