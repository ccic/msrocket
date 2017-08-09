Param
(
   [Parameter(Mandatory=$False)]
   [bool]$upload=$False,

   [Parameter(Mandatory=$False)]
   [bool]$createResource=$False
)
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)

##### include the utility functions                                   #####
. $currentWorkingDir\env_nps.ps1

$login = gLogin
gLogMsg "==login status: $login"

if ($login) {
   gLogMsg "Successfully login"
} else {
   gLogMsg "Fail to login"
   return $False
}

$sts = gSetAccountRelatedResource
gLogMsg "==Set account related: $sts"

if ($createResource) {
   $sts = create_res_grp_if_notexist $gResourceGroupName $gAzureVMLocation
   gLogMsg "==resource group: $sts"
   if ($sts -eq $False) {
       return $False
   }
   $sts = create_storage_account_if_notexist $gSubscriptionName `
                                             $gResourceGroupName `
                                             $gStorageAccount    `
                                             $gAzureStorageType  `
                                             $gAzureVMLocation
   gLogMsg "==storage: $sts"
   if ($sts -eq $False) {
       return $False
   }
   $sts = create_container_if_notexist $gResourceGroupName `
                                       $gStorageAccount    `
                                       $gStorageContainer `
                                       $gAzureContainerPermission
   gLogMsg "==storage container: $sts"
   if ($sts -eq $False) {
       return $False
   }
}

if ($upload) {
   $sts = uploadVhd $gVHDFilePath $gSubscriptionId $gResourceGroupName `
                    $gStorageAccount $gStorageContainer
   gLogMsg "==uploadVhd: $sts"
   if ($sts -eq $False) {
      return $False
   }
}

createVM $gVHDFilePath $gSubscriptionId $gResourceGroupName `
         $gStorageAccount $gStorageContainer $gAzureVMLocation `
         $gVMName $gVMSize $gLoginUser $gLoginPassword
