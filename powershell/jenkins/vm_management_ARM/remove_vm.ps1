$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

. $currentWorkingDir\env.ps1

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)
$TimeMark = Get-Date -format ss-mm-HH-M-d-yyyy
$global:LogFile = $nameWithoutExt + "-" + $TimeMark + "-log.txt"

function removeVM([String] $vmName)
{
   $vmInfo = Get-AzureVM|where {$_.Name -match $vmName}
   if ($vmInfo -ne $null) {
      $networkURI = $vmInfo.NetworkProfile.NetworkInterfaces.ReferenceUri
      $empty, $constSub, $subId, $constResGrp, $resGrp, $others = $networkURI -split '/', 6
      log_msg "remove-azurevm -Name $vmName -ResourceGroupName $resGrp -force"
      remove-azurevm -Name $vmName -ResourceGroupName $resGrp -force
   }

   $vmNetworkInterface = get-azurenetworkinterface|where {$_.Name -match $vmName}
   if ($vmNetworkInterface -ne $null) {
      log_msg "Remove-AzureNetworkInterface -Name $vmNetworkInterface.Name -ResourceGroupName $vmNetworkInterface.ResourceGroupName -force"
      Remove-AzureNetworkInterface -Name $vmNetworkInterface.Name -ResourceGroupName $vmNetworkInterface.ResourceGroupName -force
   }

   $vmVirtualNetwork = get-AzureVirtualNetwork|where {$_.Name -match $vmName}
   if ($vmVirtualNetwork -ne $null) {
      log_msg "Remove-AzureVirtualNetwork -Name $vmVirtualNetwork.Name -ResourceGroupName $vmVirtualNetwork.ResourceGroupName -force"
      Remove-AzureVirtualNetwork -Name $vmVirtualNetwork.Name -ResourceGroupName $vmVirtualNetwork.ResourceGroupName -force
   }

   $publicIp = $vmName + "ip"
   $vmPublicIp = get-AzurePublicIpAddress|where {$_.Name -match $vmName}
   if ($vmPublicIp -ne $null) {
      log_msg "Remove-AzurePublicIpAddress -Name $vmPublicIp.Name -ResourceGroupName $vmPublicIp.ResourceGroupName -force"
      Remove-AzurePublicIpAddress -Name $vmPublicIp.Name -ResourceGroupName $vmPublicIp.ResourceGroupName -force
   }

   $ret = $vmInfo = Get-AzureVM|where {$_.Name -match $vmName}
   if ($ret -ne $null) {
      log_msg "Fail to remove VM '$vmName'"
      return $False
   }
   $ret = get-azurenetworkinterface|where {$_.Name -match $vmName}
   if ($ret -ne $null) {
      log_msg "Fail to remove network interface '$vmName'"
      return $False
   }
   $ret = get-AzureVirtualNetwork|where {$_.Name -match $vmName}
   if ($ret -ne $null) {
      log_msg "Fail to remove virtual network '$vmName'"
      return $False
   }
   $ret = get-AzurePublicIpAddress|where {$_.Name -match $vmName}
   if ($ret -ne $null) {
      log_msg "Fail to remove public ip '$publicIp'"
      return $False
   }
   return $True
}

log_msg $ENV:PublishSettingsFile

login_azure 

if ($? -eq $False) {
   log_msg "Fail to login by importing the azure publish setting file"
   return $false
}

Switch-AzureMode -Name AzureResourceManager

removeVM $ENV:VMName
