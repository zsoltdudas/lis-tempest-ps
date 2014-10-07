param([string] $baseName, [string] $vm1, [string] $vm2, [string] $vm3)

function GetVMSwitch([string] $type)
{
    $vmswitch = Get-VMSwitch | Where-Object -FilterScript {$_.SwitchType -Eq $type}
    return $vmswitch
}

Try{
    $vswitch1 = $baseName + '1'
    $vsiwtch2 = $baseName + '2'
    Add-VMNetworkAdapter -VMName $vm1 -SwitchName $vswitch1
    Add-VMNetworkAdapter -VMName $vm2 -SwitchName $vswitch1
    Add-VMNetworkAdapter -VMName $vm2 -SwitchName $vsiwtch2
    Set-VMNetworkAdapter $vm2 -MacAddressSpoofing on
    Add-VMNetworkAdapter -VMName $vm3 -SwitchName $vsiwtch2
}
Catch [system.exception]{
    throw
}