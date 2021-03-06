param(
  [Parameter(Mandatory=$True)]
  [String]$VMName,

  [Parameter(Mandatory=$True)]
  [String]$Computer
  
)

## This function can only set the IP addr for the 1st NIC currently
Function Set-VMNetworkConfiguration {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,
                   Position=1,
                   ParameterSetName='Static')]
        [String[]]$IPAddress=@(),
 
        [Parameter(Mandatory=$false,
                   Position=2,
                   ParameterSetName='Static')]
        [String[]]$Subnet=@(),
 
        [Parameter(Mandatory=$false,
                   Position=3,
                   ParameterSetName='Static')]
        [String[]]$DefaultGateway = @(),
 
        [Parameter(Mandatory=$false,
                   Position=4,
                   ParameterSetName='Static')]
        [String[]]$DNSServer = @(),
 
        [Parameter(Mandatory=$false,
                   Position=0,
                   ParameterSetName='DHCP')]
        [Switch]$Dhcp
    )
 
	$query = "Select * From Msvm_ComputerSystem Where ElementName='" + $VMName + "'"
	$Vm = gwmi -namespace root\virtualization\v2 -query $query -computername $Computer
	
	$VMSettings = $vm.GetRelated('Msvm_VirtualSystemSettingData') | Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }    
    $VMNetAdapters = $VMSettings.GetRelated('Msvm_SyntheticEthernetPortSettingData')
 
    $NetworkSettings = @()
    foreach ($NetAdapter in $VMNetAdapters) {
        $NetworkSettings = $NetworkSettings + $NetAdapter.GetRelated("Msvm_GuestNetworkAdapterConfiguration")
    }
 
    $NetworkSettings[0].IPAddresses = $IPAddress
    $NetworkSettings[0].Subnets = $Subnet
    $NetworkSettings[0].DefaultGateways = $DefaultGateway
    $NetworkSettings[0].DNSServers = $DNSServer
    $NetworkSettings[0].ProtocolIFType = 4096
 
    if ($dhcp) {
        $NetworkSettings[0].DHCPEnabled = $true
    } else {
        $NetworkSettings[0].DHCPEnabled = $false
    }
 
    $Service = $VM.GetRelated('Msvm_VirtualSystemManagementService');
	$setIP = $Service.SetGuestNetworkAdapterConfiguration($VM, $NetworkSettings[0].GetText(1))
 
    if ($setip.ReturnValue -eq 4096) {
        $job=[WMI]$setip.job 
 
        while ($job.JobState -eq 3 -or $job.JobState -eq 4) {
            start-sleep 1
            $job=[WMI]$setip.job
        }
 
        if ($job.JobState -eq 7) {
            write-host "Success"
        }
        else {
            $job.GetError()
        }
    } elseif($setip.ReturnValue -eq 0) {
        Write-Host "Success"
    }
}

## This function can only set the IP addr for the 1st NIC currently
Function SetIPAddress
{
	$query = "Select * From Msvm_ComputerSystem Where ElementName='" + $VMName + "'"
	$Vm = gwmi -namespace root\virtualization\v2 -query $query -computername $Computer
	
	$VMSettings = $vm.GetRelated('Msvm_VirtualSystemSettingData') | Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }    
    $VMNetAdapters = $VMSettings.GetRelated('Msvm_SyntheticEthernetPortSettingData') 

    $NetworkSettings = @()
    foreach ($NetAdapter in $VMNetAdapters) {
		$NetworkSettings = $NetworkSettings + $NetAdapter.GetRelated("Msvm_GuestNetworkAdapterConfiguration")
    }
	for ($i = 0; $i -lt $NetworkSettings.Length; $i++) {
		Write-Host "========================================================"
		Write-Host -NoNewline "InstanceID:       "; Write-Host $NetworkSettings[$i].InstanceID
		Write-Host -NoNewline "ProtocalIFType:   "; Write-Host $NetworkSettings[$i].ProtocolIFType;
		Write-Host -NoNewline "DHCPEnabled:      "; Write-Host $NetworkSettings[$i].DHCPEnabled;
		Write-Host -NoNewline "IPAddresses:      "; Write-Host $NetworkSettings[$i].IPAddresses;
		Write-Host -NoNewline "Subnets:          "; Write-Host $NetworkSettings[$i].Subnets;
		Write-Host -NoNewline "DefaultGateways:  "; Write-Host $NetworkSettings[$i].DefaultGateways;
		Write-Host -NoNewline "DNSServer:        "; Write-Host $NetworkSettings[$i].DNSServers;
	}
	$NetworkSettings[0].IPAddresses 		= "192.168.0.23"
	$NetworkSettings[0].Subnets 			= "255.255.0.0"
    $NetworkSettings[0].DefaultGateways 	= "192.168.0.1"
    $NetworkSettings[0].DNSServers 			= "192.168.100.101"
    $NetworkSettings[0].ProtocolIFType 		= 4096

	$Service = $VM.GetRelated('Msvm_VirtualSystemManagementService');
	$setIP = $Service.SetGuestNetworkAdapterConfiguration($VM, $NetworkSettings[0].GetText(1))
 
    if ($setip.ReturnValue -eq 4096) {
        $job=[WMI]$setip.job 
 
        while ($job.JobState -eq 3 -or $job.JobState -eq 4) {
            start-sleep 1
            $job=[WMI]$setip.job
        }
 
        if ($job.JobState -eq 7) {
            write-host "Success"
        }
        else {
            $job.GetError()
        }
    } elseif($setip.ReturnValue -eq 0) {
        Write-Host "Success"
    }
}
Set-VMNetworkConfiguration -IPAddress 192.168.100.1 -Subnet 255.255.0.0 -DNSServer 192.168.100.101 -DefaultGateway 192.168.100.1
#SetIPAddress