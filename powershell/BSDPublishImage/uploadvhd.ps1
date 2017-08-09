
. .\env.ps1
####### functions ##########
function createResGrpIfNotExist(
   [String] $groupName,
   [String] $location)
{
   get-azureresourcegroup -name $groupName 
   if ($? -eq $False) {
       new-azureresourcegroup -name $groupName -location $location
       if ($? -eq $False) {
           gLogMsg "Fail to create resource group $groupName"
           return $False
       } else {
           gLogMsg "Successfully create resource group $groupName"
           return $True
       }
   } else {
       return $True
   }
}

function createStorageAccountIfNotExist(
   [String] $resGrpName,
   [String] $expectStorageAccount,
   [String] $location,
   [String] $type)
{
   try {
   Get-AzureStorageAccount -ResourceGroupName $resGrpName -AccountName $expectStorageAccount
   } catch {
      write-warning "Oops: $_"
   }
   if ($? -eq $False) {
       New-AzureStorageAccount -ResourceGroupName $resGrpName `
                               -AccountName $expectStorageAccount `
                               -Location $location `
                               -Type $type
       if ($? -eq $False) {
           gLogMsg "Fail to create storage account '$expectStorageAccount'"
           return $False
       } else {
           $sleepSec = 2
           $status = (New-AzureStorageAccount -ResourceGroupName $resGrpName `
                               -AccountName $expectStorageAccount `
                               -Location $location `
                               -Type $type).ProvisioningState
           while ($status -ne "Succeeded") {
               gLogMsg "Sleep for $sleepSec"
               Start-Sleep -s $sleepSec
               $status = (New-AzureStorageAccount -ResourceGroupName $resGrpName `
                               -AccountName $expectStorageAccount `
                               -Location $loc `
                               -Type $type).ProvisioningState
           }
           if ($status -eq "Succeeded") {
               return $True
           } else {
               return $False
	   }
       }
   } else {
       gLogMsg "Storage account '$expectStorageAccount' already existed"
       return $True
   }   
}

function createStorageContainerIfNotExist(
   [String] $resGrpName,
   [String] $storageAccount,
   [String] $containerName,
   [String] $permission)
{
   gLogMsg "Get-AzureStorageAccountKey -ResourceGroupName $resGrpName -Name $storageAccount"
   $storageKey = (Get-AzureStorageAccountKey -ResourceGroupName $resGrpName -Name $storageAccount).Key1
   gLogMsg "storage key '$storageKey'"
   $storageContext = New-AzureStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $storageKey
   gLogMsg "Get-AzureStorageContainer -Name $containerName -Context $storageContext"
   $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $storageContext
   if ($? -eq $False) {
      gLogMsg " New-AzureStorageContainer -Context $storageContext -Permission $permission -Name $containerName"
      New-AzureStorageContainer -Context $storageContext -Permission $permission -Name $containerName
      if ($? -eq $True) {
          gLogMsg "Successfully create azure storage container"
          return $True
      } else {
          gLogMsg "Fail to create azure storage container"
          return $False
      }
   } else {
      gLogMsg "Container is already existed"
      return $True
   }
}

function uploadVHD (
   [String] $VHDFilePath,
   [String] $subscriptionName,
   [String] $groupName,
   [String] $stroageAccount,
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
       $StorageKey = (Get-AzureStorageAccountKey  -StorageAccountName $storageAccount -ResourceGroupName $groupName).Key1
       if ($? -eq $False) {
           return $False
       }
       gLogMsg "Storage primary key: " $StorageKey
       $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey
       $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName

       Try
       {
           gLogMsg "Before Add-AzureVhd"
           # Upload VHD Image
           Add-AzureVhd -LocalFilePath $VHDFilePath -Destination $mediaLocation -NumberOfUploaderThreads 64 -OverWrite -ResourceGroupName $groupName
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

##### main logic #####
gValidateVHDFilePath $VHDFilePath
if ($? -eq $False) {
    return $False
}

gLoginSelectSubscription $publishSettingsFilePath $subscriptionName

##gChangeToARM

createResGrpIfNotExist $groupName $location
if ($? -eq $False) {
    return $False
}

createStorageAccountIfNotExist $groupName $storageAccount $location $storageType
if ($? -eq $False) {
    return $False
}

createStorageContainerIfNotExist $groupName $storageAccount $containerName $containerPermission
if ($? -eq $False) {
    return $False
}

uploadVHD $VHDFilePath $subscriptionName $groupName $storageAccount $containerName
if ($? -eq $False) {
    return $False
} else {
    return $True
}
