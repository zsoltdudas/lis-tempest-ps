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

param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”), [string] $controllerType=$(throw “No input”), [int] $controllerId=$(throw “No input”), [int] $lun=$(throw “No input”), [string] $vhdType=$(throw “No input”),[int] $sectorSize=$(throw “No input”), [string] $diskType=$(throw “No input”), [string] $diskSize)

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
function ConvertStringToUInt64([string] $size)
{
    $uint64Size = $null


    #
    # Make sure we received a string to convert
    #
    if (-not $size)
    {
        Write-Error -Message "ConvertStringToUInt64() - input string is null" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }


    if ($size.EndsWith("MB"))
    {
        $num = $size.Replace("MB","")
        $uint64Size = ([Convert]::ToUInt64($num)) * 1MB
    }
    elseif ($size.EndsWith("GB"))
    {
        $num = $size.Replace("GB","")
        $uint64Size = ([Convert]::ToUInt64($num)) * 1GB
    }
    elseif ($size.EndsWith("TB"))
    {
        $num = $size.Replace("TB","")
        $uint64Size = ([Convert]::ToUInt64($num)) * 1TB
    }
    else
    {
        Write-Error -Message "Invalid newSize parameter: ${size}" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }


    return $uint64Size
}

# CreateHardDrive
#
# Description
#     If the -SCSI options is false, an IDE drive is created
############################################################################
function CreateHardDrive( [string] $vmName, [string] $server, [System.Boolean] $SCSI, [int] $ControllerID,
                          [int] $Lun, [string] $vhdType, [string] $sectorSize, [string] $diskType, [string] $diskSize)
{
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
    else # Make sure the controller ID is valid for IDE
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
    else
    {

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

        $vhdName = $defaultVhdPath + $vmName + "-" + $controllerType + "-" + $controllerID + "-" + $lun + "-" + $vhdType  + "." + $diskType.ToLower()

        if(Test-Path $vhdName)
        {
            Remove-Item $vhdName
        }

        $newVhd = $null
        if ($diskSize -ne $null -and $diskSize.Length -ne 0)
        {
            $intDiskSize = ConvertStringToUInt64 $diskSize
        }
        else
        {
            $intDiskSize = $global:MinDiskSize
        }
        switch ($vhdType)
        {
            "Dynamic"
                {
                    $newvhd = New-VHD -Path $vhdName  -size $intDiskSize -ComputerName $server -Dynamic -LogicalSectorSize ([int] $sectorSize)
                }
            "Fixed"
                {
                    $newVhd = New-VHD -Path $vhdName -size $intDiskSize -ComputerName $server -Fixed
                }
            default
                {
                    Write-Output "Error: unknow vhd type of ${vhdType}"
                    exit -1
                }
        }
        if ($newVhd -eq $null)
        {
            write-output "Error: New-VHD failed to create the new .vhd file: $($vhdName)"
            exit -1
        }

        $ERROR.Clear()
        Add-VMHardDiskDrive -VMName $vmName -Path $vhdName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $server
        if ($ERROR.Count -gt 0)
        {
            Write-Output "ERROR: Add-VMHardDiskDrive failed to add drive on ${controllerType} ${controllerID} ${Lun}s"
            $ERROR[0].Exception
            exit -1
        }

        Write-Output "INFO: Success"
    }

}

# Main entry point for script
############################################################################

$SCSI = $false
if ($controllerType -eq "SCSI")
{
    $SCSI = $true
}

if (@("Fixed", "Dynamic", "PassThrough") -notcontains $vhdType)
{
    Write-Output "ERROR: Unknown disk type: $vhdType"
    exit -1
}

Write-Output "CreateHardDrive $vmName $hvServer $diskType $scsi $controllerID $Lun $vhdType $sectorSize"
Write-Output $vhdType
$sts = CreateHardDrive -vmName $vmName -server $hvServer -SCSI:$SCSI -ControllerID $controllerID -Lun $Lun -vhdType $vhdType -sectorSize $sectorSize -diskType $diskType -diskSize $diskSize
if (-not $sts[$sts.Length-1])
{
    write-output "ERROR: Failed to create hard drive"
    $sts
    exit -1
}
