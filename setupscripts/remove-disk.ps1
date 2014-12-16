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

############################################################################

param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”), [string] $diskName=$(throw “No input”))

############################################################################
#
# Main entry point for script
#
############################################################################
$vm = Get-VM $vmName
if($vm)
{
    Stop-VM -vmName $vmName -force
}
$vhdxName = $diskName

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

Get-ChildItem $defaultVhdPath -Filter $vhdxName | `
Foreach-Object{
	
    $error.Clear()
	"Info: Deleting vhdx file ${vhdxName}"
	Remove-Item -Path $_.FullName
	if ($error.Count -gt 0)
	{
		"Error: Failed to delete VHDx File "
		$error[0].Exception
		exit -1
	}
}
"Successfully deleted ${vhdxName}"