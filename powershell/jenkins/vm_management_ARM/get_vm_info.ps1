$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

. $currentWorkingDir\env.ps1

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)
$TimeMark = Get-Date -format ss-mm-HH-M-d-yyyy
$global:LogFile = $nameWithoutExt + "-" + $TimeMark + "-log.txt"

function getAzureVMInfo(
   [String] $vmName)
{
   log_msg "existing vm: $vmName"
   
   $vmInfo = Get-AzureVM|where {$_.Name -match $vmName}
   $networkURI = $vmInfo.NetworkProfile.NetworkInterfaces.ReferenceUri
   $empty, $constSub, $subId, $constResGrp, $resGrp, $others = $networkURI -split '/', 6
   
   log_msg "networkURI: $networkURI"

   $storageProfile = $vmInfo.StorageProfile
   $vhdURI = $storageProfile.OSDisk.SourceImage.Uri
   $httpHeader, $content = $vhdURI -split '//' 
   $blobName, $container, $vhdName = $content -split '/'

   $vhdNameWithoutExt, $ext = $vhdName -split '\.'

   log_msg "storageProfile: $storageProfile"
   $storageAccount, $others = $blobName -split '\.'
  
   $global:AzureGroupAccount      = $resGrp
   $global:AzureStorageAccount    = $storageAccount
   $global:AzureStorageContainer  = $container
   $global:VHDFileName            = $vhdNameWithoutExt
   $global:VMSize                 = $vmInfo.HardwareProfile.VirtualMachineSize
   $global:VMLocation             = $vmInfo.Location
}

#log_env_parameters $LogFile
log_msg $ENV:PublishSettingsFile

login_azure 

Switch-AzureMode -Name AzureResourceManager

#login

if ($? -eq $False) {
   log_msg "Fail to login by importing the azure publish setting file"
   return $false
}

setup_AzureVM_env

getAzureVMInfo $ENV:ExistingVMName

log_msg "subscription: $SubscriptionName"
log_msg "group:$AzureGroupAccount"
log_msg "storage: $AzureStorageAccount"
log_msg "container: $AzureStorageContainer"
log_msg "vhdFile: $VHDFileName"
log_msg "vhdName: $ENV:VMName"
log_msg "VMSize: $VMSize"
log_msg "VMLocation: $VMLocation"
log_msg "virtualNetwork: $AzureVirtualNetworkName"

deploy_vm $SubscriptionName $AzureGroupAccount $AzureStorageAccount `
                 $AzureStorageContainer $VHDFileName $ENV:VMName $VMSize `
                 $VMLocation $ENV:LoginUser $ENV:LoginPassword $AzureVirtualNetworkName
