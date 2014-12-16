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

param([string] $vmName=$(throw “No input”), [string] $hvServer=$(throw “No input”), [string] $diskName=$(throw “No input”))

############################################################################
#
# Main entry point for script
#
############################################################################

$vhdxName = $diskName
$vhdxDisks = Get-VMHardDiskDrive -Verbose -VMName $vmName
if ($? -ne 0)
{
	"Error: Get-VMHardDiskDrive failed. "
	exit -1
}

foreach ($vhdx in $vhdxDisks)
{
	$vhdxPath = $vhdx.Path
	if ($vhdxPath -match $vhdxName)
	{
		"Info : Removing drive ${vhdxName}"
		Remove-VMHardDiskDrive -Verbose -vmName $vmName -ControllerType $vhdx.controllerType -ControllerNumber $vhdx.controllerNumber -ControllerLocation $vhdx.ControllerLocation -ComputerName $hvServer
		if ($? -ne 0)
		{
			"Error: Remove-VMHardDiskDrive failed. "
			exit -1
		}
        else 
        { 
          "Successfully detached $vhdxPath"
        }
	}
}
