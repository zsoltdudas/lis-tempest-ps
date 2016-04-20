########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################

<#
.Synopsis
	Sends a NMI to a given VM by using the Debug-VM cmdlet

.Description
	The script will send a NMI to the specific VM. Script must be executed 
	under PowerShell running with Administrator rights, unprivileged user 
	can not send the NMI to VM.
	This must be used along with the nmi_verify_interrupt.sh bash script to 
	check if the NMI is successfully detected by the Linux guest VM.

.Parameter vmName
    Name of the VM to perform the test with.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    A semicolon separated list of test parameters.

.Example
    .\NMI_Send_Interrupt.ps1 -vmName "MyVM" -hvServer "localhost"
#>

param([string] $vmName=$(throw "No input"), [string] $hvServer=$(throw "No input"))

$Error.Clear()

#
# Checking if PowerShell is running as Administrator
#
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    "Error: You do not have Administrator rights to run this script."
    exit -1
}

#
# The VM must be in a running state
#
$vm = Get-VM $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: Cannot find the VM ${vmName} on server ${hvServer}"
    exit -1
}

if ($($vm.State) -ne [Microsoft.HyperV.PowerShell.VMState]::Running )
{
    "Error: VM ${vmName} is not in the running state!"
    exit -1
}

#
# Sending a NMI to VM
#
Debug-VM -Name $vmName -InjectNonMaskableInterrupt -ComputerName $hvServer -Confirm:$False -Force
if($?) {
	"Info: Successfully sent a NMI to VM $vmName"
}
else {
    "Error: NMI could not be sent to VM $vmName"
    exit -1
}
