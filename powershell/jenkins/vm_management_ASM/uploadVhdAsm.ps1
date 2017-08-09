param(
  [Parameter(Mandatory=$True)]
  [bool]$createResource = $False,

  [Parameter(Mandatory=$True)]
  [bool]$uploadVHD = $False,

  [Parameter(Mandatory=$True)]
  [bool]$createImage = $False
)
##### set the global var: $LogFile, which is used in function gLogMsg #####

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)
$TimeMark = Get-Date -format ss-mm-HH-M-d-yyyy
$global:LogFile = $nameWithoutExt + "-" + $TimeMark + "-log.txt"

##### include the utility functions                                   #####
. $currentWorkingDir\env_asm.ps1


function createStorageAccountIfNotExist(
   [String] $subscriptionName,
   [String] $storageAccount,
   [String] $storageType,
   [String] $location)
{
   gLogMsg "get-azurestorageaccount -storageaccountname $storageAccount"
   get-azurestorageaccount -storageaccountname $storageAccount
   if ($? -eq $False) {
       new-azurestorageaccount -storageaccountname $storageAccount -Location $location -Type $storageType
       if ($? -eq $True) {
          Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
          if ($? -eq $False) {
             return $False
          } else {
             return $True
          }
       } else {
          return $False
       }
   } else {
       Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
       gLogMsg "Storage account '$storageAccount' already existed!"
   }
   return $True
}

function createContainerIfNotExist(
   [String] $containerName,
   [String] $containerPermission)
{
   get-azurestoragecontainer -Name $containerName
   if ($? -eq $False) {
       gLogMsg "New-AzureStorageContainer -Name $containerName -Permission $containerPermission"
       New-AzureStorageContainer -Name $containerName -Permission $containerPermission
       if ($? -eq $True) {
          return $True
       } else {
          return $False
       }
   } else {
       gLogMsg "Container '$containerName' already existed!"
   } 
}

function uploadVhd(
   [String] $VHDFilePath,
   [String] $subscriptionName,
   [String] $storageAccount,
   [String] $containerName)
{
   Try
   {
       # build Azure Storage File Name: LocalFileName-yyyy-MM-dd-HH-mm-ss.vhd
       $FileName = [IO.Path]::GetFileNameWithoutExtension($VHDFilePath)
       $BlobFileName = $FileName + ".vhd"

       # Prepare subscription and storage account
       Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
       Select-AzureSubscription -SubscriptionName $subscriptionName
       $StorageKey = (Get-AzureStorageKey -StorageAccountName $storageAccount).Primary
       if ($? -eq $False) {
           return $False
       }
       gLogMsg "Storage primary key: $StorageKey"
       $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey
       $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName

       Try
       {
           gLogMsg "Before Add-AzureVhd"
           # Upload VHD Image
           Add-AzureVhd -LocalFilePath $VHDFilePath -Destination $mediaLocation -NumberOfUploaderThreads 64 -OverWrite
           if ($? -eq $True) {
               gLogMsg "'$BlobFileName' uploaded success."
               return $True
           } else {
               gLogMsg "'$BlobFileName' upload failed."
               return $False
           }
       } Catch {
           gLogMsg "Upload VHD Image Failed."
           gLogMsg $ERROR[0].Exception
       }
   } Catch {
       gLogMsg "Upload Failed."
       gLogMsg $ERROR[0].Exception
   }
   return $False
}

function addVMImageIfNotExist(
   [String] $vmImageName,
   [String] $vmImageRoot,
   [String] $VHDFilePath,
   [String] $subscriptionName,
   [String] $storageAccount,
   [String] $containerName)
{
   gLogMsg "Get-AzureVMImage -ImageName $vmImageName"
   $sts = Get-AzureVMImage -ImageName $vmImageName 
   if ($sts -eq $null) {
       # build Azure Storage File Name: LocalFileName-yyyy-MM-dd-HH-mm-ss.vhd
       $FileName = [IO.Path]::GetFileNameWithoutExtension($VHDFilePath)
       $BlobFileName = $FileName + ".vhd"

       # Prepare subscription and storage account
       Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
       Select-AzureSubscription -SubscriptionName $subscriptionName
       $StorageKey = (Get-AzureStorageKey -StorageAccountName $storageAccount).Primary
       if ($? -eq $False) {
           return $False
       }
       gLogMsg "Storage primary key: $StorageKey"
       $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey
       $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName

       $imageWithTheSameMedia = Get-AzureVMImage | where {$_.ImageName -match $vmImageRoot}
       if ($imageWithTheSameMedia -ne $null) {
           $previousImageName = (Get-AzureVMImage | where {$_.ImageName -match $vmImageRoot}).ImageName
           gLogMsg "The '$mediaLocation' has already been bind to another image '$previousImageName'"
           if ($gUseExistingImage -eq $True) {
               $global:gVMImageName = $previousImageName
               gLogMsg "Previous VM image '$gVMImageName' is used"
               return $True;
           } else {
               gLogMsg "Remove-AzureVMImage -ImageName $previousImageName"
               Remove-AzureVMImage -ImageName $previousImageName
               $imageWithTheSameMedia = Get-AzureVMImage | where {$_.ImageName -match $vmImageRoot}
               if ($imageWithTheSameMedia -ne $null) {
                   gLogMsg "Fail to remove the existing vm image '$previousImageName'"
                   return $False
               } else {
                   gLogMsg "Successfully remove the existing vm image '$previousImageName'"
               }
           }New-AzureVM : ResourceNotFound: The hosted service does not exist.
       }

       gLogMsg "Add-AzureVMImage -ImageName $vmImageName -medialocation $mediaLocation  -OS $gOStype"
       Add-AzureVMImage -ImageName $vmImageName -medialocation $mediaLocation  -OS $gOStype
       $sts = Get-AzureVMImage -ImageName $vmImageName 
       if ($sts -ne $null) {
          gLogMsg "Successfully create Azure VM Image '$vmImageName'"
          return $True
       } else {
          gLogMsg "Fail to create Azure VM Image '$vmImageName'"
          return $False
       }
   } else {
       $mediaLink = $sts.MediaLink
       gLogMsg "Image has already existed '$mediaLink'"
       return $True
   }
}

function createAzureService(
   [String] $serviceName,
   [String] $location,
   [String] $description,
   [String] $label)
{
   $sts = Get-AzureService -ServiceName $ServiceName
   if ($sts -eq $null) {
      gLogMsg "New-AzureService -ServiceName $servicename -Location $location -Description $description -Label $label"
      New-AzureService -ServiceName $servicename -Location $location -Description $description -Label $label
      if ($? -eq $True) {
         gLogMsg "Successfully create service '$serviceName'"
         return $True
      } else {
         gLogMsg "Fail to create service '$serviceName'"
         return $False
      }
   } else {
      gLogMsg "Service name '$serviceName' already existed!"
      return $True
   }
}

function createVM(
   [String] $serviceName,
   [String] $subscription,
   [String] $storageAccount,
   [String] $VMName,
   [String] $VMSize,
   [String] $vmImageName,
   [String] $vmUsername,
   [String] $vmPassword)
{
   gLogMsg "Start to create $VMName"
   gLogMsg "set-azuresubscription -subscriptionname $subscription -currentstorageaccount $storageAccount"
   set-azuresubscription -subscriptionname $subscription -currentstorageaccount $storageAccount
   gLogMsg "New-AzureVM -ServiceName $servicename -VMs (( New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $vmImageName | Add-AzureProvisioningConfig -Linux -LinuxUser $vmUsername -Password $vmPassword ))"
   New-AzureVM -ServiceName $servicename -VMs (( New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $vmImageName | Add-AzureProvisioningConfig -Linux -LinuxUser $vmUsername -Password $vmPassword ))
   if ($? -ne $True ) {
      gLogMsg "Fail to create VM $VMName"
      return $False
   } else {
      gLogMsg "Successfully create VM $VMName"
      return $True
   }
}

$ret = gLogin
if ($ret -eq $False) {
   return $False
}

$ret = gSetAccountRelatedResource
if ($ret -eq $False) {
   return $False
}

if ($createResource -eq $True) {
   createStorageAccountIfNotExist $gSubscriptionName $gStorageAccount $gAzureStorageType $gAzureVMLocation
   if ($? -eq $False) {
      return $False
   }

   createContainerIfNotExist $gStorageContainer $gAzureContainerPermission
   if ($? -eq $False) {
      return $False
   }
}

if ($uploadVHD -eq $True) {
   $ret = uploadVhd $gVHDFilePath $gSubscriptionName $gStorageAccount $gStorageContainer
   if ($ret -eq $False) {
      return $False
   }
}

if ($createImage -eq $True) {
   $ret = addVMImageIfNotExist $gVMImageName $gVMImageRoot $gVHDFilePath $gSubscriptionName $gStorageAccount $gStorageContainer
   if ($ret -eq $False) {
      return $False
   }
}

$ret = createAzureService $gCloudServiceName $gAzureVMLocation $gServiceDescription $gServiceLabel
if ($ret -eq $False) {
   return $False
}

$ret = createVM $gCloudServiceName $gSubscriptionName $gStorageAccount $gVMName $gVMSize $gVMImageName $gLoginUser $gLoginPassword
if ($ret -eq $False) {
   return $False
}
