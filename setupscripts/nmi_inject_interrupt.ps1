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
	Attempts to send NMI type interrupts to a VM in various states.

.Description
	The script will send a NMI to a given VM. Interrupts are successful	only 
	if the VM is running. Other VM states - Stopped, Saved and Paused must fail. 
	This is the expected behavior and the test case will return the results as such.

.Parameter vmName
    Name of the VM to perform the test with.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Example
    .\NMI_different_vmStates.ps1 -vmName "MyVM" -hvServer "localhost"
#>

param([string] $vmName=$(throw "No input"), [string] $hvServer=$(throw "No input"))

$errorstr = "Cannot inject a non-maskable interrupt into the virtual machine"

#
# Attempting to send the NMI, which must fail in order for the test to be valid
#
$nmistatus = Debug-VM -Name $vmName -InjectNonMaskableInterrupt -ComputerName $hvServer -Confirm:$False -Force 2>&1

if (($nmistatus | select-string -Pattern $errorstr -Quiet) -eq "True") {
	"Info: Non-Maskable interrupt sent successfully."
	}
else {
	Write-Output "Error: Could not send the Non-Maskable interrupt!"
	exit -1
}

exit 0