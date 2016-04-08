param ([String] $vmName, [String] $hvServer)

$isoFilename = $null

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


#######################################################################
#
# Main script body
#
#######################################################################

$isoFilename = "${vmName}.iso"

$error.Clear()

#
# Make sure the DVD drive exists on the VM
#
$dvd = Get-VMDvdDrive $vmName -ComputerName $hvServer -ControllerLocation 0 -ControllerNumber 1
if ($dvd)
{
    Remove-VMDvdDrive $dvd -Confirm:$False
    if($? -ne "True")
    {
        Write-Output "Error: Cannot remove DVD drive from ${vmName}"
        exit -1
    }
}

#
# Make sure the .iso file exists on the HyperV server
#
if (-not ([System.IO.Path]::IsPathRooted($isoFilename)))
{
    $obj = Get-WmiObject -ComputerName $hvServer -Namespace "root\virtualization\v2" -Class "MsVM_VirtualSystemManagementServiceSettingData"

    $defaultVhdPath = $obj.DefaultVirtualHardDiskPath

    if (-not $defaultVhdPath)
    {
        Write-Output "Error: Unable to determine VhdDefaultPath on HyperV server ${hvServer}"
        exit -1
    }

    if (-not $defaultVhdPath.EndsWith("\"))
    {
        $defaultVhdPath += "\"
    }

    $isoFilename = $defaultVhdPath + $isoFilename

}

$isoFileInfo = GetRemoteFileInfo $isoFilename $hvServer
if (-not $isoFileInfo)
{
    Write-Output "Error: The .iso file $isoFilename does not exist on HyperV server ${hvServer}"
    exit -1
}

#
# Insert the .iso file into the VMs DVD drive
#
Add-VMDvdDrive -VMName $vmName -Path $isoFilename -ControllerNumber 1 -ControllerLocation 0 -ComputerName $hvServer -Confirm:$False
if ($? -ne "True")
{
    Write-Output "Error: Unable to mount"
    exit -1
}