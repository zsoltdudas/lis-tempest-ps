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


param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”), [string] $controllerType=$(throw “No input”), [int] $controllerId=$(throw “No input”), [int] $lun=$(throw “No input”), [string] $vhdFormat=$(throw “No input”))

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
        exit -1
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
            exit -1
        }
        "Info : Controller successfully added"
    }
    return $True
}

#######################################################################
# Create parentVhd
#######################################################################
function CreateParentVhd([string] $vhdFormat, [string] $server)
{
    $hostInfo = Get-VMHost -ComputerName $server
    if (-not $hostInfo)
        {
            Write-Output "Error: Unable to collect Hyper-V settings for ${server}"
            exit -1
        }

    $defaultVhdPath = $hostInfo.VirtualHardDiskPath
    if (-not $defaultVhdPath.EndsWith("\"))
        {
            $defaultVhdPath += "\"
        }

    $parentVhdName = $defaultVhdPath + $vmName + "_Parent." + $vhdFormat
    if(Test-Path $parentVhdName)
        {
            Remove-Item $parentVhdName
        }

    $fileInfo = GetRemoteFileInfo -filename $parentVhdName -server $server
    if (-not $fileInfo)
        {
        $nv = New-Vhd -Path $parentVhdName -SizeBytes 2GB -Dynamic -ComputerName $server
        if ($nv -eq $null)
            {
                Write-Output "Error: New-VHD failed to create the new .vhd file: $parentVhdName"
                exit -1
            }
        }
        return $parentVhdName
}

#######################################################################
# Main script body
#######################################################################


#
# Make sure we have access to the Microsoft Hyper-V snapin
#
$hvModule = Get-Module Hyper-V
if ($hvModule -eq $NULL)
{
    import-module Hyper-V
    $hvModule = Get-Module Hyper-V
}

if ($hvModule.companyName -ne "Microsoft Corporation")
{
    Write-Output "Error: The Microsoft Hyper-V PowerShell module is not available"
    exit -1
}

$parentVhd = $null

#
# Make sure we have all the required data to do our job
#
if (-not $controllerType)
{
    Write-Output "Error: No controller type specified in the test parameters"
    exit -1
}

if ($controllerID -eq $null -or $controllerID.Length -eq 0)
{
    Write-Output "Error: No controller ID specified in the test parameters"
    exit -1
}

if ($Lun -eq $null -or $Lun.Length -eq 0)
{
    Write-Output "Error: No LUN specified in the test parameters"
    exit -1
}

$SCSI = $false
if ($controllerType -eq "SCSI")
{
    $SCSI = $true
}

###################################
if (-not $parentVhd)
{
    # Create a new ParentVHD
    $parentVhd = CreateParentVhd $vhdFormat $hvServer
    if ($parentVhd -eq $False)
    {
        Write-Output "Error: Failed to create parent $vhdFormat on $hvServer"
        exit -1
    }
}

# Make sure the disk does not already exist
if ($SCSI)
{
    if ($ControllerID -lt 0 -or $ControllerID -gt 3)
    {
        Write-Output "Error: CreateHardDrive was passed a bad SCSI Controller ID: $ControllerID"
        exit -1
    }

    # Create the SCSI controller if needed
    $sts = CreateController $vmName $hvServer $controllerID
    if (-not $sts[$sts.Length-1])
    {
        Write-Output "Error: Unable to create SCSI controller $controllerID"
        exit -1
    }
}
else # Make sure the controller ID is valid for IDE
{
    if ($ControllerID -lt 0 -or $ControllerID -gt 1)
    {
        Write-Output "Error: CreateHardDrive was passed an invalid IDE Controller ID: $ControllerID"
        exit -1
    }
}

$drives = Get-VMHardDiskDrive -VMName $vmName -ComputerName $hvServer -ControllerType $controllerType -ControllerNumber $controllerID -ControllerLocation $lun
if ($drives)
{
    write-output "Error: drive $controllerType $controllerID $Lun already exists"
    return $retVal
}

$hostInfo = Get-VMHost -ComputerName $hvServer
if (-not $hostInfo)
{
    Write-Output "Error: Unable to collect Hyper-V settings for ${hvServer}"
    exit -1
}

$defaultVhdPath = $hostInfo.VirtualHardDiskPath
if (-not $defaultVhdPath.EndsWith("\"))
{
    $defaultVhdPath += "\"
}


if ($parentVhd.EndsWith(".vhd"))
{
    # To Make sure we do not use exisiting Diff disk, del if exisit
    $vhdName = $defaultVhdPath + ${vmName} +"-" + ${controllerType} + "-" + ${controllerID}+ "-" + ${lun} + "-" + "Diff.vhd"
}
else
{
    $vhdName = $defaultVhdPath + ${vmName} +"-" + ${controllerType} + "-" + ${controllerID}+ "-" + ${lun} + "-" + "Diff.vhdx"
}

#$vhdFileInfo = GetRemoteFileInfo -filename $vhdName -server $hvServer
$vhdFileInfo = GetRemoteFileInfo  $vhdName  $hvServer
if ($vhdFileInfo)
{
    $delSts = $vhdFileInfo.Delete()
    if (-not $delSts -or $delSts.ReturnValue -ne 0)
    {
        Write-Output "Error: unable to delete the existing .vhd file: ${vhdFilename}"
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
    Write-Output "Error: Cannot find parent VHD file: ${parentVhdFilename}"
    exit -1
}

#
# Create the .vhd file
$newVhd = New-Vhd -Path $vhdName -ParentPath $parentVhdFilename -ComputerName $hvServer -Differencing
if (-not $newVhd)
{
    Write-Output "Error: unable to create a new .vhd file"
    exit -1
}
#
# Just double check to make sure the .vhd file is a differencing disk
#
if ($newVhd.ParentPath -ne $parentVhdFilename)
{
    Write-Output "Error: the VHDs parent does not match the provided parent vhd path"
    exit -1
}

#
# Attach the .vhd file to the new drive
#
$error.Clear()
$disk = Add-VMHardDiskDrive -VMName $vmName -ComputerName $hvServer -ControllerType $controllerType -ControllerNumber $controllerID -ControllerLocation $lun -Path $vhdName
if ($error.Count -gt 0)
{
    Write-Output "Error: Add-VMHardDiskDrive failed to add drive on ${controllerType} ${controllerID} ${Lun}s"
    exit -1
}