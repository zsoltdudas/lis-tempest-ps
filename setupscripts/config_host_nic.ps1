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
    [string]$Name,
    [Parameter(Mandatory=$true)]
    [string]$IP,
    [Parameter(Mandatory=$true)]
    [string]$Prefix
)
Import-Module NetAdapter

Try{
    $net_if = Get-NetAdapter -Name "$Name"
    $net_if | Set-NetIPInterface -DHCP Disabled
    $net_if | New-NetIPAddress -AddressFamily IPv4 -IPAddress $IP `
    -PrefixLength $Prefix -Type Unicast
}
Catch [system.exception]{
    throw
}