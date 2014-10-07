param([string] $baseName)
function CreateVMSwitch([string] $type)
{
    $vswitch1 = $baseName + '1'
    $vsiwtch2 = $baseName + '2'
    New-VMSwitch -Name $vswitch1 -SwitchType $type
    New-VMSwitch -Name $vsiwtch2 -SwitchType $type
}


Try{
    CreateVMSwitch("Private")
}
Catch [system.exception]{
    throw
}
