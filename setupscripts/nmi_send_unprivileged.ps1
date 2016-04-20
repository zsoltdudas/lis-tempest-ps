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
	Attempts to send a NMI as an unprivileged user.

.Description
	The script will try to send a NMI to a specific VM. A user with insufficient 
	privileges attempting to send a NMI will receive an error. This is the expected
	behavior and the test case will return the results as such.

.Parameter vmName
    Name of the VM to perform the test with.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Example
    .\NMI_SendAs_Unprivileged.ps1 -vmName "MyVM" -hvServer "localhost"
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)

$random = Get-Random -minimum 1024 -maximum 4096
$errorstr = "You do not have permission to perform the operation"
$Password = "P@ssw0rd123"

#######################################################################
#
# function CreateLocalUser ()
# This function create a new Windows local user account
#
#######################################################################
function CreateLocalUser()
{
    $ComputerName = $env:COMPUTERNAME
    $Computer = [adsi]"WinNT://$ComputerName"
    $UserName = "TestUser_$random"
    $User = $Computer.Create("user",$UserName)
    $User.SetPassword($Password)
    $User.SetInfo()
    
    if(!$?)
    {
	Write-Output "Unable to create a temporary username." 
        exit -1
    }
    else
    {
		Write-Output "Successfully created temporary username: $UserName"
    }
}

#######################################################################
#
# function DeleteLocalUser ()
# This function will delete a Windows local user account
#
#######################################################################
function DeleteLocalUser()
{
    $ComputerName = $env:COMPUTERNAME
    $Computer = [adsi]"WinNT://$ComputerName"
    $UserName = "TestUser_$random"
    $User = $Computer.Delete("user",$UserName)
    if(!$?)
    {
        Write-Output "Unable to delete the temporary username $UserName" 
        exit -1
    }
    else
    {
        Write-Output "Successfully removed the temporary username $UserName"
    }
}

#
# Verifies if the VM exists and if it is running
#
$VM = Get-VM $vmName -ComputerName $hvServer
if (-not $VM)
{
    Write-Output "Error: Cannot find the VM ${vmName} on server ${hvServer}"
    exit -1
}

if ($($vm.State) -ne [Microsoft.HyperV.PowerShell.VMState]::Running )
{
    Write-Output "Error: VM ${vmName} is not running!"
    exit -1
}

#
# Creating a local user account with limited privileges on the Hyper-V host
#
CreateLocalUser
if(!$?)
{
    Write-Output "Error: User could not be created"
    exit -1
}

#
# Create a credential object
#
$passwd = ConvertTo-SecureString -string $Password -asplaintext -force
$creds = New-Object -Typename System.Management.Automation.PSCredential -ArgumentList "TestUser_$random",$passwd
if(!$?)
{
    Write-Output "Error: Could not created the credential object"
    DeleteLocalUser
    exit -1
}

#
# Attempting to send NMI to Linux VM using the unprivileged credentials through a job
#
$cmd = [Scriptblock]::Create("Debug-VM -Name $vmName -InjectNonMaskableInterrupt -ComputerName $hvServer 2>&1")
$newJob = Start-job -scriptblock $cmd -credential $creds
start-sleep 6

Get-Job -id $newJob.Id
$job = Get-Job -id $newJob.Id

While ($job.State -ne "Completed")
{
    if($job.State -eq "Failed")
    {
        Write-Output "Error: Task job to send the NMI interrupt has failed!"
        DeleteLocalUser
        exit -1
    }
    start-sleep 6
}
$nmi_status = Receive-Job -Id $newJob.Id -Wait -WriteJobInResults -WriteEvents
$nmi_status
#
# Deleting the previously created user account
#
DeleteLocalUser
if(!$?)
{
    Write-Output "Error: Temporary restricted user could not be deleted!"
}

#
# Verifying the job output
#
$match = $nmi_status | select-string -Pattern $errorstr -Quiet
if ($match -eq "True")
{
    Write-Output "Test passed! NMI could not be sent to Linux VM with unprivileged user."
}
else
{
    Write-Output "Error: NMI request was sent to Linux VM using unprivileged user account!"
	Write-Output "Issue encountered: $nmi_status"
    exit -1
}
