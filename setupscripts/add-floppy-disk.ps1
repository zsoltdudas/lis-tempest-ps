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


param ([String] $vmName, [String] $hvServer)


#############################################################
#
# Main script body
#
#############################################################

$vfdPath = $null


# If a .vfd file does not exist, create one
#
#
$hostInfo = Get-VMHost -ComputerName $hvServer
if (-not $hostInfo)
{
    Write-Output "ERROR: Unable to collect Hyper-V settings for ${server}"
    exit -1
}

$defaultVhdPath = $hostInfo.VirtualHardDiskPath
if (-not $defaultVhdPath.EndsWith("\"))
{
    $defaultVhdPath += "\"
}

$vfdPath = "${defaultVhdPath}${vmName}.vfd"
if(Test-Path $vfdPath)
{
    Remove-Item $vfdPath
}

#
# The .vfd file does not exist, so create one
#
$newVfd = New-VFD -Path $vfdPath -ComputerName $hvServer
if (-not $newVfd)
{
    Write-Output "Error: Unable to create VFD file ${vfdPath}"
    exit -1
}

#
# Add the vfd
#
Set-VMFloppyDiskDrive -Path $vfdPath -VMName $vmName -ComputerName $hvServer
if ($? -ne "True")
{
    Write-Output "Error: Unable to mount floppy"
    exit -1
}
