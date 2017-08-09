
$env_config_script = "env_jenkins.ps1"   ## include the variables defined in Jenkins

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$env_config_ps1    = join-path $currentWorkingDir $env_config_script

. $env_config_ps1

#### global variables ####
$global:gAzureStorageType           = "Standard_LRS"
$global:gAzureContainerPermission   = "Blob"
$global:gProjectName                = "rocket"
$global:gStoragePostfix             = "storage"
$global:gContainerPostfix           = "vhds"
$global:gOStype                     = "Linux"

#### utility functions ####
#### gLogMsg depends on global var $LogFile ####
function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   #echo $OutputMsg
   echo $OutputMsg >> $global:LogFile
}

function getAliasFromEmail([String] $email) {
   $alias, $domain = $email -split '@', 2
   $final_alias = $alias.Replace("-","")
   return $final_alias
}

function gLoginSelectSubscription(
  [String] $publishSettingsFilePath,
  [String] $subscriptionName)
{
   Import-AzurePublishSettingsFile -publishsettingsFile $publishSettingsFilePath
   if ($? -eq $False) {
       gLogMsg "Fail to import subscription settings file"
       return $False
   }
   Select-AzureSubscription -Current -SubscriptionName $subscriptionName
   return $?
}

function gLogin()
{
   get_publish_settings_file     ## it set the publish settings file path to global var $gPublishSettingsFilePath
   if (!(test-path $gPublishSettingsFilePath)) {
      gLogMsg "Cannot find the uploaded publish settings file from '$gPublishSettingsFilePath'"
      return $false
   }

   $publishConfig = [xml] (Get-Content -Path $gPublishSettingsFilePath)

   $global:gSubscriptionName = ($publishConfig.PublishData.PublishProfile.Subscription |select Name).Name
   gLogMsg "Subscription: $gSubscriptionName"
   $ret = gLoginSelectSubscription $gPublishSettingsFilePath $gSubscriptionName
   return $ret
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

#### this function depends on gLogin and VHDFile valdiation
function gSetAccountRelatedResource()
{   
   $global:gUserEmail = (get-azureaccount|where-object {$_.type -like "user"}).Id
   $global:gAlias = getAliasFromEmail $gUserEmail
   
   $global:gStorageAccount   = $gAlias + $gProjectName + $gStoragePostfix
   $global:gStorageContainer = $gAlias + $gProjectName + $gContainerPostfix

   $global:gCloudServiceName = $ENV:VMCloudServiceName
   $global:gServiceDescription = $ENV:CloudServiceDescription
   $global:gServiceLabel     = $ENV:CloudServiceLabel
   $global:gLoginUser        = $ENV:LoginUser
   $global:gLoginPassword    = $ENV:LoginPassword

   $global:gVMName           = $ENV:VMName
   $global:gVMSize           = $ENV:VMSize
   
   get_vm_image_name_postfix
   $global:gVMImageRoot      = $gAlias + $gProjectName
   $global:gVMImageName      = $gVMImageRoot + $gVMImageNamePostfix
   $global:gUseExistingImage = $ENV:UseExistedImage
   get_azure_location

   get_vhd_file_location

   gLogMsg "Azure login user email: '$gUserEmail'"
   gLogMsg "Azure login user alias: '$gAlias'"
   gLogMsg "Subscription:           '$gSubscriptionName'"
   gLogMsg "Storage account:        '$gStorageAccount'"
   gLogMsg "Storage container:      '$gStorageContainer'"
   gLogMsg "VM location:            '$gAzureVMLocation'"
   gLogMsg "VM image name:          '$gVMImageName'"
   gLogMsg "Use existed VM Image:   '$gUseExistingImage'"
   gLogMsg "VHD file path:          '$gVHDFilePath'"
   gLogMsg "Cloud service name:     '$gCloudServiceName'"
   gLogMsg "Cloud service description '$gServiceDescription'"
   gLogMsg "Cloud service label:    '$gServiceLabel'"
   gLogMsg "Login user name:        '$gLoginUser'"
   gLogMsg "Login user password:    '$gLoginPassword'"
   gLogMsg "VM name:                '$gVMName'"
   gLogMsg "VM size:                '$gVMSize'"

   if ($gCloudServiceName -eq $null) {
      gLogMsg "Cloud service name is not specified!"
      return $False
   }
   if ($gServiceDescription -eq $null) {
      gLogMsg "Cloud service description is not specified!"
      return $False
   }
   if ($gServiceLabel -eq $null) {
      gLogMsg "Cloud service label is not specified!"
      return $False
   }
   $ret = gValidateVHDFilePath $gVHDFilePath
   if ($ret -eq $False) {
      return $False
   }

   return $True
}
