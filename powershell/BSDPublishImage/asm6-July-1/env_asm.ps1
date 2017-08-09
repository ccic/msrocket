$env_config_script = "env_config.ps1"
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$env_config_ps1    = join-path $currentWorkingDir $env_config_script

. $env_config_ps1

#### global variables ####
$storageAccount       = "honzhanbsdimgstore"
$containerName        = "honzhanbsdimgcontainer"
$location             = "west europe"
$subscriptionName     = "OSTC BSD"
$containerPermission  = "Off"
$imageDescription     = "FreeBSD 10.3 for Microsoft Azure provided by Microsoft Corporation. FreeBSD is an advanced computer operating system used to power modern servers, desktops and embedded platforms. The FreeBSD Logo and the mark FreeBSD are registered trademarks of The FreeBSD Foundation and are used by Microsoft Corporation with the permission of The FreeBSD Foundation."

$offer               = "FreeBSD"
$sku                 = "10.3"
$publisher           = "Microsoft"
$osType              = "Linux"
$vmLabelImageFamily  = "FreeBSD 10.3"
$recommendedVMSize   = "Large"
#$eula                = "http://www.redhat.com/licenses/cloud_CSSA/Red_Hat_Cloud_Software_Subscription_Agreement_for_Microsoft_Azure.pdf"
$publishSettingsFilePath = join-path $currentWorkingDir "OSTC-BSD.publishsettings"

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
   Select-AzureSubscription -Current -SubscriptionName $subscriptionName
}

function gLogin()
{
   gLoginSelectSubscription $publishSettingsFilePath $subscriptionName
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

function gImportModules()
{
   import-module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Compute\PIR.psd1"
}
