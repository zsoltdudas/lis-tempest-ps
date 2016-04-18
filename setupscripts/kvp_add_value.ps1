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
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################


############################################################################
#
# Main script body
#
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams, [string] $Key=$(throw "No input"), [int] $Value=$(throw "No input"), [int] $Pool=$(throw "No input"))

$retVal = $false

#
# Check input arguments
#
if (-not $vmName)
{
    Write-Output "Error: no VMName was specified""Error: VM name is null"
    exit -1
}

if (-not $hvServer)
{
    Write-Output "Error: hvServer is null"
    exit -1
}

if (-not $Key)
{
    Write-Output "Error: Missing testParam Key to be added"
    exit -1
}
if (-not $Value)
{
    Write-Output "Error: Missing testParam Value to be added"
    exit -1
}

write-output "Info : Adding Key=value of: ${key}=${value}"

#
# Add the Key Value pair to the Pool 0 on guest OS.
#
$VMManagementService = Get-WmiObject -class "Msvm_VirtualSystemManagementService" -namespace "root\virtualization\v2" -ComputerName $hvServer
if (-not $VMManagementService)
{
    Write-Output "Error: Unable to create a VMManagementService object"
    exit -1
}

$VMGuest = Get-WmiObject -Namespace root\virtualization\v2 -ComputerName $hvServer -Query "Select * From Msvm_ComputerSystem Where ElementName='$VmName'"
if (-not $VMGuest)
{
    Write-Output "Error: Unable to create VMGuest object"
    exit -1
}

$Msvm_KvpExchangeDataItemPath = "\\$hvServer\root\virtualization\v2:Msvm_KvpExchangeDataItem"
$Msvm_KvpExchangeDataItem = ([WmiClass]$Msvm_KvpExchangeDataItemPath).CreateInstance()
if (-not $Msvm_KvpExchangeDataItem)
{
    Write-Output "Error: Unable to create Msvm_KvpExchangeDataItem object"
    exit -1
}

#
# Populate the Msvm_KvpExchangeDataItem object
#
$Msvm_KvpExchangeDataItem.Source = 0
$Msvm_KvpExchangeDataItem.Name = $Key
$Msvm_KvpExchangeDataItem.Data = $Value

#
# Set the KVP value on the guest
#
$result = $VMManagementService.AddKvpItems($VMGuest, $Msvm_KvpExchangeDataItem.PSBase.GetText(1))
$job = [wmi]$result.Job

while($job.jobstate -lt 7) {
    $job.get()
}

if ($job.ErrorCode -ne 0)
{
    Write-Output "Error: Unable to add KVP value to guest"
    Write-Output "       error code $($job.ErrorCode)"
    exit -1
}

if ($job.Status -ne "OK")
{
    Write-Output "Error: KVP add job did not complete with status OK"
    exit -1
}

Write-Output "Info : KVP item added successfully on guest"