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


param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”), [string] $controllerType=$(throw “No input”), [int] $controllerId=$(throw “No input”), [int] $lun=$(throw “No input”), [string] $parentType=$(throw “No input”))

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
# CreateController
#
# Description
#     Create a SCSI controller if one with the controllerId does not
#     already exist.
#
############################################################################
function CreateController([string] $vmName, [string] $server, [string] $controllerId)
{
    #
    # Initially, we will limit this to 4 SCSI controllers...
    #
    if ($controllerId -lt 0 -or $controllerId -gt 3)
    {
        write-output "    Error: Bad SCSI controller ID: $controllerId"
        return $False
    }

    #
    # Check if the controller already exists.
    #
    $scsiCtrl = Get-VMScsiController -VMName $vmName -ComputerName $hvServer
    if ($scsiCtrl.Length -1 -ge $controllerId)
    {
        "Info : SCSI ontroller already exists"
    }
    else
    {
        $error.Clear()
        Add-VMScsiController -VMName $vmName -ComputerName $hvServer
        if ($error.Count -gt 0)
        {
            "    Error: Add-VMScsiController failed to add 'SCSI Controller $controllerId'"
            $error[0].Exception
            return $False
        }
        "Info : Controller successfully added"
    }
    return $True
}


#######################################################################
#
# Main script body
#
#######################################################################


#
# Make sure we have all the required data to do our job
#
if (-not $controllerType)
{
    "Error: No controller type specified in the test parameters"
    return $False
}

if ($controllerID -eq $null -or $controllerID.Length -eq 0)
{
    "Error: No controller ID specified in the test parameters"
    return $False
}

if ($Lun -eq $null -or $Lun.Length -eq 0)
{
    "Error: No LUN specified in the test parameters"
    return $False
}

if ($parentType -eq "vhd") {
    $parentVhd = "DynamicParent.vhd"
}
elseif ($parentType -eq "vhdx"){
    $parentVhd = "VHDXParentDiff.vhdx"
}
else {
    "Specify the test vhd type with either vhd or vhdx"
    return $false
}

$SCSI = $false
if ($controllerType -eq "SCSI")
{
    $SCSI = $true
}
#
# Make sure the disk does not already exist
#
if ($SCSI)
{
    if ($controllerId -lt 0 -or $controllerId -gt 3)
    {
        "Error: CreateHardDrive was passed a bad SCSI Controller ID: $controllerId"
        return $false
    }

    #
    # Create the SCSI controller if needed
    #
    $sts = CreateController $vmName $hvServer $controllerId
    if (-not $sts[$sts.Length-1])
    {
        "Error: Unable to create SCSI controller $controllerId"
        exit -1
    }
}
else # Make sure the controller ID is valid for IDE
{
    if ($controllerId -lt 0 -or $controllerId -gt 1)
    {
        "Error: CreateHardDrive was passed an invalid IDE Controller ID: $controllerId"
        exit -1
    }
}

$drives = Get-VMHardDiskDrive -VMName $vmName -ComputerName $hvServer -ControllerType $controllerType -ControllerNumber $controllerId -ControllerLocation $lun
if ($drives)
{
    "Error: drive $controllerType $controllerId $Lun already exists"
    exit -1
}

$hostInfo = Get-VMHost -ComputerName $hvServer
if (-not $hostInfo)
{
    "Error: Unable to collect Hyper-V settings for ${hvServer}"
    exit -1
}

$defaultVhdPath = $hostInfo.VirtualHardDiskPath
if (-not $defaultVhdPath.EndsWith("\"))
{
    $defaultVhdPath += "\"
}


if ($parentVhd.EndsWith(".vhd"))
{
    # To Make sure we do not use exisiting  Diff disk , del if exisit
    $vhdName = $defaultVhdPath + ${vmName} +"-" + ${controllerType} + "-" + ${controllerId}+ "-" + ${lun} + "-" + "Diff.vhd"
}
else
{
    $vhdName = $defaultVhdPath + ${vmName} +"-" + ${controllerType} + "-" + ${controllerId}+ "-" + ${lun} + "-" + "Diff.vhdx"
}

$vhdFileInfo = GetRemoteFileInfo  $vhdName  $hvServer
if ($vhdFileInfo)
{
    $delSts = $vhdFileInfo.Delete()
    if (-not $delSts -or $delSts.ReturnValue -ne 0)
    {
        "Error: unable to delete the existing .vhd file: ${vhdFilename}"
        exit -1
    }
}

#
# Make sure the parent VHD is an absolute path, and it exists
#
$parentVhdFilename = $parentVhd
if (-not [System.IO.Path]::IsPathRooted($parentVhd))
{
    $parentVhdFilename = $defaultVhdPath + $parentVhd
}

$parentFileInfo = GetRemoteFileInfo  $parentVhdFilename  $hvServer
if (-not $parentFileInfo)
{
    "Error: Cannot find parent VHD file: ${parentVhdFilename}"
    exit -1
}

#
# Create the .vhd file
$newVhd = New-Vhd -Path $vhdName  -ParentPath $parentVhdFilename  -ComputerName $hvServer -Differencing
if (-not $newVhd)
{
    "Error: unable to create a new .vhd file"
    exit -1
}
#
# Just double check to make sure the .vhd file is a differencing disk
#
if ($newVhd.ParentPath -ne $parentVhdFilename)
{
    "Error: the VHDs parent does not match the provided parent vhd path"
    exit -1
}

#
# Attach the .vhd file to the new drive
#
$error.Clear()
$disk = Add-VMHardDiskDrive -VMName $vmName -ComputerName $hvServer -ControllerType $controllerType -ControllerNumber $controllerId -ControllerLocation $lun -Path $vhdName
if ($error.Count -gt 0)
{
    "Error: Add-VMHardDiskDrive failed to add drive on ${controllerType} ${controllerId} ${Lun}s"
    $error[0].Exception
    exit -1
}
