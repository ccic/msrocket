$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function createStorageAccountIfNotExist(
   [String] $storageAccount,
   [String] $location)
{
   get-azurestorageaccount -storageaccountname $storageAccount
   if ($? -eq $False) {
       new-azurestorageaccount -storageaccountname $storageAccount -Location $location
       if ($? -eq $True) {
          return $True
       } else {
          return $False
       }
   } else {
       gLogMsg "Storage account '$storageAccount' already existed!"
   }
   return $True
}

function createContainerIfNotExist(
   [String] $containerName,
   [String] $permission)
{
   get-azurestoragecontainer -Name $containerName
   if ($? -eq $False) {
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
       $StorageKey = (Get-AzureStorageKey -StorageAccountName $stroageAccount).Primary
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

gLogin

createStorageAccountIfNotExist $storageAccount $location
if ($? -eq $False) {
   return $False
}

Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
if ($? -eq $False) {
   return $False
}

createContainerIfNotExist $containerName $containerPermission
if ($? -eq $False) {
   return $False
}

uploadVhd $VHDFilePath $subscriptionName $storageAccount $containerName
return $?
