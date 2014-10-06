function CreateVMSwitch([string] $type)
{
    $privateSwitches = Get-VMSwitch | Where-Object -FilterScript {$_.SwitchType -Eq $type}
    if( $privateSwitches.Length -eq 0)
    {
        New-VMSwitch -Name "private1" -SwitchType $type
        New-VMSwitch -Name "private2" -SwitchType $type
    }
}

CreateVMSwitch("Private")
