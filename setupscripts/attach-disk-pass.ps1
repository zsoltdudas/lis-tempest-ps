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

param([string] $vmName=$(throw "No input"), [string] $hvServer=$(throw "No input"), [string] $controllerType=$(throw "No input"), [int] $controllerId=$(throw "No input"), [int] $lun=$(throw "No input"), [string] $vhdType=$(throw "No input"))

$global:MinDiskSize = 1GB

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
        exit -1
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
            exit -1
        }
        Write-Output "INFO: Controller successfully added"
    }
    return $True
}
# CreateHardDrive
#
# Description
#     Create an IDE drive is created
############################################################################
function CreateHardDrive( [string] $vmName, [string] $server, [int] $ControllerID, [int] $Lun, [string] $vhdType, [string] $controllerType)
{
    Write-Output "INFO: CreateHardDrive $vmName $server $controllerID $lun"

    # Make sure it's a valid IDE ControllerID.  For IDE, it must 0 or 1.
    # For SCSI it must be 0, 1, 2, or 3
    if ($controllerType -eq "SCSI")
    {

        if ($ControllerID -lt 0 -or $ControllerID -gt 3)
        {
            Write-Output "ERROR: CreateHardDrive was passed an bad SCSI Controller ID: $ControllerID"
            exit -1
        }

        # Create the SCSI controller if needed
        $sts = CreateController $vmName $server $controllerID
        if (-not $sts[$sts.Length-1])
        {
            Write-Output "ERROR: Unable to create SCSI controller $controllerID"
            exit -1
        }
    }
    else
    {
        if ($ControllerID -lt 0 -or $ControllerID -gt 1)
        {
            Write-Output "ERROR: CreateHardDrive was passed an invalid IDE Controller ID: $ControllerID"
            exit -1
        }
    }
    # If the hard drive exists, complain...
    $drive = Get-VMHardDiskDrive -VMName $vmName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $server
    if ($drive)
    {
        Write-Output "ERROR: drive $controllerType $controllerID $Lun already exists"
        exit -1
    }

    # Create the .vhd file if it does not already exist, then create the drive and mount the .vhdx
    $hostInfo = Get-VMHost -ComputerName $server
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

    $vhdName = $defaultVhdPath + $vmName + "-" + $controllerType + "-" + $controllerID + "-" + $lun + "-" + $vhdType  + ".vhd"

    if(Test-Path $vhdName)
    {
        Remove-Item $vhdName
    }
    $newVhd = $null
    $newVhd = New-VHD -Path $vhdName -size $global:MinDiskSize -ComputerName $server -Fixed
    if ($newVhd -eq $null)
    {
        write-output "Error: New-VHD failed to create the new .vhd file: $($vhdName)"
        exit -1
    }

    $newVhd = $newVhd | Mount-VHD -Passthru
    $phys_disk = $newVhd | Initialize-Disk -PartitionStyle MBR -PassThru
    $phys_disk | Set-Disk -IsOffline $true

        $ERROR.Clear()
        $phys_disk | Add-VMHardDiskDrive -VMName $vmName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $server
        if ($ERROR.Count -gt 0)
        {
            Write-Output "ERROR: Add-VMHardDiskDrive failed to add drive on ${controllerType} ${controllerID} ${Lun}s"
            $ERROR[0].Exception
            exit -1
        }

        Write-Output "INFO: Success"
}


# Main entry point for script
############################################################################

if ( "PassThrough" -ne $vhdType)
{
    Write-Output "ERROR: Unknown disk type: $vhdType"
    exit -1
}

Write-Output "CreateHardDrive $vmName $hvServer $controllerID $Lun $vhdType"
$sts = CreateHardDrive -vmName $vmName -server $hvServer -ControllerID $controllerID -Lun $Lun -vhdType $vhdType -controllerType $controllerType
if (-not $sts[$sts.Length-1])
{
    write-output "ERROR: Failed to create hard drive"
    $sts
    exit -1
}
