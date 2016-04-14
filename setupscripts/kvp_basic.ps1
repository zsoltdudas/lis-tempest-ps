########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
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


param( [String] $vmName,
       [String] $hvServer
)


function KvpToDict($rawData)
{
    <#
    .Synopsis
        Convert the KVP data to a PowerShell dictionary.
    .Description
        Convert the KVP xml data into a PowerShell dictionary.
        All keys are added to the dictionary, even if their
        values are null.
    .Parameter rawData
        The raw xml KVP data.
    .Example
        KvpToDict $myKvpData
    #>

    $dict = @{}

    foreach ($dataItem in $rawData)
    {
        $key = ""
        $value = ""
        $xmlData = [Xml] $dataItem

        foreach ($p in $xmlData.INSTANCE.PROPERTY)
        {
            if ($p.Name -eq "Name")
            {
                $key = $p.Value
            }

            if ($p.Name -eq "Data")
            {
                $value = $p.Value
            }
        }
        $dict[$key] = $value
    }

    return $dict
}


#######################################################################
#
# Main script body
#
#######################################################################

#
# Make sure the required arguments were passed
#
if (-not $vmName)
{
    Write-Output "Error: no VMName was specified"
    exit -1
}

if (-not $hvServer)
{
    Write-Output "Error: No hvServer was specified"
    exit -1
}

#
# Create a data exchange object and collect KVP data from the VM
#
$Vm = Get-WmiObject -Namespace root\virtualization\v2 -ComputerName $hvServer -Query "Select * From Msvm_ComputerSystem Where ElementName=`'$VMName`'"
if (-not $Vm)
{
    Write-Output "Error: Unable to the VM '${VMName}' on the local host"
    exit -1

$Kvp = Get-WmiObject -Namespace root\virtualization\v2 -ComputerName $hvServer -Query "Associators of {$Vm} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent"
if (-not $Kvp)
{
    Write-Output "Error: Unable to retrieve KVP Exchange object for VM '${vmName}'"
    exit -1
}

$kvpData = $Kvp.GuestIntrinsicExchangeItems


$dict = KvpToDict $kvpData

#
# write out the kvp data so it appears in the log file
#
foreach ($key in $dict.Keys)
{
    $value = $dict[$key]
    Write-Output ("  {0,-27} : {1}" -f $key, $value)
}
#
#

$osInfo = GWMI Win32_OperatingSystem -ComputerName $hvServer
if (-not $osInfo)
{
    Write-Output "Error: Unable to collect Operating System information"
    exit -1
}
#
#Create an array of key names specific to a build of Windows.
#Hopefully, These will not change in future builds of Windows Server.
#
$osSpecificKeyNames = $null
switch ($osInfo.BuildNumber)
{
    "9200" { $osSpecificKeyNames = @("OSBuildNumber", "OSVendor", "OSSignature") }
    "9600" { $osSpecificKeyNames = @("OSName", "ProcessorArchitecture", "OSMajorVersion", "IntegrationServicesVersion", "OSBuildNumber", "NetworkAddressIPv4", "NetworkAddressIPv6", "OSDistributionName", "OSDistributionData", "OSPlatformId") }
    default { $osSpecificKeyNames = $null }
}
$testPassed = $True
foreach ($key in $osSpecificKeyNames)
{
    if (-not $dict.ContainsKey($key))
    {
        Write-Output "Error: The key '${key}' does not exist"
        exit -1
    }
}