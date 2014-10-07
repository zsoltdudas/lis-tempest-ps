param([string] $baseName)
function DeleteVMSwitch()
{
    $vswitch1 = $baseName + '1'
    $vsiwtch2 = $baseName + '2'
    Remove-VMSwitch -Name $vswitch1 -Force
    Remove-VMSwitch -Name $vsiwtch2 -Force
}


Try{
    DeleteVMSwitch
}
Catch [system.exception]{
    throw
}
