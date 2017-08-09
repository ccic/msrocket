$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function getVMImageBillingTag(
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
           gLogMsg "Fail to get storage primary key"
           return $False
       }
       gLogMsg "Storage primary key: $StorageKey"
       $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey
       $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName

       $tag = gGetBillingTag $storageAccount $StorageKey $mediaLocation
       gLogMsg "Billing tag is '$tag'"
   } Catch {
       gLogMsg "Upload Failed."
       gLogMsg $ERROR[0].Exception
   }
}

getVMImageBillingTag $VHDFilePath $subscriptionName $storageAccount $containerName
