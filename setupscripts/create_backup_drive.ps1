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

param([string] $vmName=$(throw "No input"), [string] $hvServer=$(throw "No input"))


############################################################################
function CreateBackupDrive( [string] $vmName, [string] $server)
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

    $vhdName = $defaultVhdPath + $vmName + "-backup_disk.vhd"

    if(Test-Path $vhdName)
    {
        Remove-Item $vhdName
    }
    $newVhd = $null

    $ERROR.Clear()
    $fullSize = 4*1024*1024*1024 #4GB
    Get-VMHardDiskDrive -ComputerName $server -VMName $vmName | foreach {
    if($_.Path.Contains('vhd'))
    {
        $fullSize += $($_  | Get-VHD ).FileSize
    }
    }

    if ($ERROR.Count -gt 0)
    {
        Write-Output "ERROR: "
        $ERROR[0].Exception
        exit -1
    }
    $newVhd = New-VHD -Path $vhdName -size $fullSize -ComputerName $server -Fixed
    if ($newVhd -eq $null)
    {
        write-output "Error: New-VHD failed to create the new .vhd file: $($vhdName)"
        exit -1
    }

    $newVhd = $newVhd | Mount-VHD -Passthru
    $phys_disk = $newVhd | Initialize-Disk -PartitionStyle MBR -PassThru
    $partition = $phys_disk | New-Partition -AssignDriveLetter -UseMaximumSize
    sleep 1
    $volume = Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "backup" -Confirm:$false

    if ($ERROR.Count -gt 0)
    {
        Write-Output "ERROR: "
        $ERROR[0].Exception
        exit -1
    }
    return $partition.DriveLetter
}


# Main entry point for script
############################################################################

$sts = CreateBackupDrive -vmName $vmName -server $hvServer
if (-not $sts[$sts.Length-1])
{
    write-output "ERROR: Failed to create hard drive"
    $sts
    exit -1
}
return $sts
