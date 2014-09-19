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

<#
.Synopsis
This setup script, that will run before the VM is booted, will Add VHDx Hard Driver to VM.

.Description
    This is a setup script that has to be run while the VM is turned off.
    The script will create a .vhdx file, and mount it to the
    specified hard drive. If the hard drive does not exist, it
    will be created.

    The  scripts will always pass the vmName, hvServer, and a
    string of testParams from the test definition separated by
    semicolons. The testParams for this script identify disk
    controllers, hard drives, .vhd type, and sector size.  The
    testParamss have the format of:

        ControllerType=Controller Index, Lun or Port, vhd type, sector size

    The following are some examples

        SCSI=0,0,Dynamic,4096 : Add SCSI Controller 0, hard drive on Lun 0, .vhd type Dynamic, sector size of 4096
        SCSI=1,0,Fixed,512    : Add SCSI Controller 1, hard drive on Lun 0, .vhd type Fixed, sector size of 512 bytes
        IDE=0,1,Dynamic,512   : Add IDE hard drive on IDE 0, port 1, .vhd type Fixed, sector size of 512 bytes
        IDE=1,1,Fixed,4096    : Add IDE hard drive on IDE 1, port 1, .vhd type Fixed, sector size of 4096 bytes

    All setup and cleanup scripts must return a boolean ($true or $false)
    to indicate if the script completed successfully.

    Where
        ControllerType   = The type of disk controller.  IDE or SCSI
        Controller Index = The index of the controller, 0 based.
                         Note: IDE can be 0 - 1, SCSI can be 0 - 3
        Lun or Port      = The IDE port number of SCSI Lun number
        Vhd Type         = Type of VHD to use.
                         Valid VHD types are:
                             Dynamic
                             Fixed

    The following are some examples

        SCSI=0,0,Dynamic,4096 : Add a hard drive on SCSI controller 0, Lun 0, vhd type of Dynamic disk with logical sector size of 4096
        IDE=1,1,Fixed,4096  : Add a hard drive on IDE controller 1, IDE port 1, vhd type of Fixed disk with logical sector size of 4096

.Parameter vmName
    Name of the VM to remove disk from.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    attach-vhdx.ps1 -vmName myVM -hvServer localhost -testParams "SCSI=0,0,Dynamic,4096;"

#>
param([string] $vmName, [string] $hvServer, [string] $controllerType, [int] $controllerId, [int] $lun, [string] $vhdType, [int] $sectorSize, [string] $diskType)

$global:MinDiskSize = 1GB
$global:DefaultDynamicSize = 127GB

# GetRemoteFileInfo()
#
# Description:
#     Use WMI to retrieve file information for a file residing on the
#     Hyper-V server.
#
# Return:
#     A FileInfo structure if the file exists, null otherwise.
#######################################################################
function GetRemoteFileInfo([String] $filename, [String] $server )
{
    $fileInfo = $null

    if (-not $filename)
    {
        return $null
    }

    if (-not $server)
    {
        return $null
    }

    $remoteFilename = $filename.Replace("\", "\\")
    $fileInfo = Get-WmiObject -query "SELECT * FROM CIM_DataFile WHERE Name='${remoteFilename}'" -computer $server

    return $fileInfo
}

# CreateController
#
# Description
#     Create a SCSI controller if one with the ControllerID does not
#     already exist.
############################################################################
function CreateController([string] $vmName, [string] $server, [string] $controllerID)
{
    # Initially, we will limit this to 4 SCSI controllers...
    if ($ControllerID -lt 0 -or $controllerID -gt 3)
    {
        write-output "ERROR: bad SCSI controller ID: $controllerID"
        return $False
    }

    # Check if the controller already exists.
    $scsiCtrl = Get-VMScsiController -VMName $vmName -ComputerName $server
    if ($scsiCtrl.Length -1 -ge $controllerID)
    {
        Write-Output "INFO: SCI ontroller already exists"
    }
    else
    {
        $ERROR.Clear()
        Add-VMScsiController -VMName $vmName -ComputerName $server
        if ($ERROR.Count -gt 0)
        {
            Write-Output "ERROR: Add-VMScsiController failed to add 'SCSI Controller $ControllerID'"
            $ERROR[0].Exception
            return $False
        }
        Write-Output "INFO: Controller successfully added"
    }
    return $True
}

# CreateHardDrive
#
# Description
#     If the -SCSI options is false, an IDE drive is created
############################################################################
function CreateHardDrive( [string] $vmName, [string] $server, [System.Boolean] $SCSI, [int] $ControllerID,
                          [int] $Lun, [string] $vhdType, [string] $sectorSizes, [string] $diskType)
{
    $retVal = $false

    Write-Output "INFO: CreateHardDrive $vmName $server $scsi $controllerID $lun $vhdType"

    # Make sure it's a valid IDE ControllerID.  For IDE, it must 0 or 1.
    # For SCSI it must be 0, 1, 2, or 3
    $controllerType = "IDE"
    if ($SCSI)
    {
        $controllerType = "SCSI"

        if ($ControllerID -lt 0 -or $ControllerID -gt 3)
        {
            Write-Output "ERROR: CreateHardDrive was passed an bad SCSI Controller ID: $ControllerID"
            return $false
        }

        # Create the SCSI controller if needed
        $sts = CreateController $vmName $server $controllerID
        if (-not $sts[$sts.Length-1])
        {
            Write-Output "ERROR: Unable to create SCSI controller $controllerID"
            return $false
        }
    }
    else # Make sure the controller ID is valid for IDE
    {
        if ($ControllerID -lt 0 -or $ControllerID -gt 1)
        {
            Write-Output "ERROR: CreateHardDrive was passed an invalid IDE Controller ID: $ControllerID"
            return $False
        }
    }

    # If the hard drive exists, complain...
    $drive = Get-VMHardDiskDrive -VMName $vmName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $server
    if ($drive)
    {
        Write-Output "ERROR: drive $controllerType $controllerID $Lun already exists"
        return $False
    }
    else
    {

        # Create the .vhd file if it does not already exist, then create the drive and mount the .vhdx
        $hostInfo = Get-VMHost -ComputerName $server
        if (-not $hostInfo)
        {
            Write-Output "ERROR: Unable to collect Hyper-V settings for ${server}"
            return $False
        }

        $defaultVhdPath = $hostInfo.VirtualHardDiskPath
        if (-not $defaultVhdPath.EndsWith("\"))
        {
            $defaultVhdPath += "\"
        }

    $vhdName = $defaultVhdPath + $vmName + "-" + $controllerType + "-" + $controllerID + "-" + $lun + "-" + $vhdType  + "." + $diskType.ToLower()


        $fileInfo = GetRemoteFileInfo -filename $vhdName -server $server
        if (-not $fileInfo)
        {
            $nv = New-Vhd -Path $vhdName -size $global:MinDiskSize -Dynamic:($vhdType -eq "Dynamic") -LogicalSectorSize ([int] $sectorSize)  -ComputerName $server
            if ($nv -eq $null)
            {
                Write-Output "ERROR: New-VHD failed to create the new .vhd file: $($vhdName)"
                return $False
            }
        }

        $ERROR.Clear()
        Add-VMHardDiskDrive -VMName $vmName -Path $vhdName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $server
        if ($ERROR.Count -gt 0)
        {
            Write-Output "ERROR: Add-VMHardDiskDrive failed to add drive on ${controllerType} ${controllerID} ${Lun}s"
            $ERROR[0].Exception
            return $retVal
        }

        Write-Output "INFO: Success"
        $retVal = $True
    }

    return $retVal
}

# Main entry point for script
############################################################################

$retVal = $true

# Check input arguments
if ($vmName -eq $null -or $vmName.Length -eq 0)
{
    Write-Output "ERROR: VM name is null"
    return $False
}

if ($hvServer -eq $null -or $hvServer.Length -eq 0)
{
    Write-Output "ERROR: hvServer is null"
    return $False
}

$SCSI = $false
if ($controllerType -eq "SCSI")
{
    $SCSI = $true
}

if (@("Fixed", "Dynamic", "PassThrough") -notcontains $vhdType)
{
    Write-Output "ERROR: Unknown disk type: $vhdType"
    $retVal = $false
    continue
}

Write-Output "CreateHardDrive $vmName $hvServer $diskType $scsi $controllerID $Lun $vhdType $sectorSize"
$sts = CreateHardDrive -vmName $vmName -server $hvServer -SCSI:$SCSI -ControllerID $controllerID -Lun $Lun -vhdType $vhdType -sectorSize $sectorSize -diskType $diskType
if (-not $sts[$sts.Length-1])
{
    write-output "ERROR: Failed to create hard drive"
    $sts
    $retVal = $false
    continue
}

return $retVal
