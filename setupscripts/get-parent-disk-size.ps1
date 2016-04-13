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


param([string] $hvServer=$(throw "No input"), [string] $diskName=$(throw "No input"))


#######################################################################
#
# GetRemoteFileInfo()
#
# Description:
#     Use WMI to retrieve file information for a file residing on the
#     Hyper-V server.
#
# Return:
#     A FileInfo structure if the file exists, null otherwise.
#
#######################################################################
function GetRemoteFileInfo([String] $filename, [String] $server )
{
    $fileInfo = $null


    $remoteFilename = $filename.Replace("\", "\\")
    $fileInfo = Get-WmiObject -query "SELECT * FROM CIM_DataFile WHERE Name='${remoteFilename}'" -computer $server

    return $fileInfo
}


############################################################################
#
# Main script body
#
############################################################################


#
# Display a little info about our environment
#

$hostInfo = Get-VMHost -ComputerName $hvServer
if (-not $hostInfo)
{
    "Error: Unable to collect Hyper-V settings for ${hvServer}"
    return $False
}

$defaultVhdPath = $hostInfo.VirtualHardDiskPath
if (-not $defaultVhdPath.EndsWith("\"))
{
    $defaultVhdPath += "\"
}


#$vhdName = $defaultVhdPath + ${vmName} +"-" + ${controllerType} + "-" + ${controllerID}+ "-" + ${lun} + "-" + "Diff.vhd"
$vhdName = $defaultVhdPath + ${diskName}

#
# The .vhd file should have been created by our
# setup script. Make sure the .vhd file exists.
#
$vhdFileInfo = GetRemoteFileInfo $vhdName $hvServer
if (-not $vhdFileInfo)
{
    "Error: VHD file does not exist: ${vhdName}"
    exit -1
}

#
# Make sure the .vhd file is a differencing disk
#
$vhdInfo = Get-VHD -path $vhdName -ComputerName $hvServer
if (-not $vhdInfo)
{
    "Error: Unable to retrieve VHD information on VHD file: ${vhdFilename}"
    exit -1
}

if ($vhdInfo.VhdType -ne "Differencing")
{
    "Error: VHD `"${vhdName}`" is not a Differencing disk"
    exit -1
}

#
# Collect info on the parent VHD
#
$parentVhdFilename = $vhdInfo.ParentPath

$parentFileInfo = GetRemoteFileInfo $parentVhdFilename $hvServer
if (-not $parentFileInfo)
{
    "Error: Unable to collect file information on parent VHD `"${parentVhd}`""
    exit -1
}

$parentDiskSize = $parentFileInfo.FileSize

return $parentDiskSize
