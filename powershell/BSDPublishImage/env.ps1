
#### global variables ####
$containerPermission = "Off"
$storageType         = "Standard_LRS"
$location            = "west us"
$subscriptionName    = "OSTC BSD"

$dateMark            = Get-Date -Format yyyy-MM-dd
$prefix              = "honzhan-bsd-img-"
$groupName           = $prefix + "group-" + $dateMark
$storageAccount      = "honzhanbsdimgstorage" #$prefix + $dateMark
$containerName       = $prefix + "container-" + $dateMark

$vmImageName         = "FreeBSD103"
$osType              = "Linux"
$vmLabelImageFamily  = "FreeBSD 10.3 of Microsoft"
$recommendedVMSize   = "Large"
$VHDFilePath         = "\\sh-ostc-th51dup\d$\vm\vhd\AzureFreeBSD103.vhd"

$publishSettingsFilePath = join-path (pwd).path "OSTC-BSD.publishsettings"

#### utility functions ####
function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   echo $OutputMsg
}

function gLoginSelectSubscription(
  [String] $publishSettingsFilePath,
  [String] $subscriptionName)
{
   Import-AzurePublishSettingsFile -publishsettingsFile $publishSettingsFilePath
   Set-AzureSubscription -SubscriptionName $subscriptionName
}

function gChangeToARM()
{
   switch-azuremode -name AzureResourceManager
}

function gValidateVHDFilePath(
   [String] $VHDFilePath)
{
   if (!(test-path $VHDFilePath -PathType Leaf)) {
       gLogMsg "VHD file $VHDFilePath is not existed!"
       return $false
   }
   return $True
}
