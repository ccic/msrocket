param(
  [Parameter(Mandatory=$True)]
  [String]$VMName,

  [Parameter(Mandatory=$True)]
  [String]$Computer
)

Function Get-NetworkConfiguration{
	param(
		[Parameter(Mandatory=$True)]
		[String]$VMName,

		[Parameter(Mandatory=$True)]
		[String]$Computer
	)

	$query = "Select * From Msvm_ComputerSystem Where ElementName='" + $VMName + "'"
	$Vm = gwmi -namespace root\virtualization\v2 -query $query -computername $Computer
	
	$VMSettings = $vm.GetRelated('Msvm_VirtualSystemSettingData') | Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }    
    $VMNetAdapters = $VMSettings.GetRelated('Msvm_SyntheticEthernetPortSettingData') 

	
    $NetworkSettings = @()
    foreach ($NetAdapter in $VMNetAdapters) {
		$NetworkSettings = $NetworkSettings + $NetAdapter.GetRelated("Msvm_GuestNetworkAdapterConfiguration")
    }
	for ($i = 0; $i -lt $NetworkSettings.Length; $i++) {
		Write-Host -NoNewline "InstanceID:       "; Write-Host $NetworkSettings[$i].InstanceID
		Write-Host -NoNewline "ProtocalIFType:   "; Write-Host $NetworkSettings[$i].ProtocolIFType;
		Write-Host -NoNewline "DHCPEnabled:      "; Write-Host $NetworkSettings[$i].DHCPEnabled;
		Write-Host -NoNewline "IPAddresses:      "; Write-Host $NetworkSettings[$i].IPAddresses;
		Write-Host -NoNewline "Subnets:          "; Write-Host $NetworkSettings[$i].Subnets;
		Write-Host -NoNewline "DefaultGateways:  "; Write-Host $NetworkSettings[$i].DefaultGateways;
		Write-Host -NoNewline "DNSServer:        "; Write-Host $NetworkSettings[$i].DNSServers;
	}
}

Get-NetworkConfiguration $VMName $Computer