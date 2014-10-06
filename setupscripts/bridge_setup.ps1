param([string] $vm1, [string] $vm2, [string] $vm3)

function GetVMSwitch([string] $type)
{
    $vmswitch = Get-VMSwitch | Where-Object -FilterScript {$_.SwitchType -Eq $type}
    return $vmswitch
}

$vmswitch = GetVMSwitch("Private")

$pr1 = $vmswitch[0].Name
$pr2 = $vmswitch[1].Name

Add-VMNetworkAdapter -VMName $vm1 -SwitchName $pr1
Add-VMNetworkAdapter -VMName $vm2 -SwitchName $pr1
Add-VMNetworkAdapter -VMName $vm2 -SwitchName $pr2
Set-VMNetworkAdapter $vm2 -MacAddressSpoofing on
Add-VMNetworkAdapter -VMName $vm3 -SwitchName $pr2
