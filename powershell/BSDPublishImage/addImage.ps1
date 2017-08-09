. .\env.ps1

function addVMImage(
   [String] $imageName,
   [String] $osType,
   [String] $labelImgFamily,
   [String] $recommendedVMSize,
   [String] $VHDFilePath,
   [String] $subscriptionName,
   [String] $groupName,
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
       $StorageKey = (Get-AzureStorageAccountKey  -StorageAccountName $storageAccount -ResourceGroupName $groupName).Key1
       if ($? -eq $False) {
           return $False
       }
       gLogMsg "Storage primary key: " $StorageKey
       $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey
       $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName

       Add-AzureVMImage -ImageName $imageName -MediaLocation $mediaLocation -OS $osType -Label $labelImgFamily `
                        -Eula "http://www.freebsd.org" -RecommendedVMSize $recommendedVMSize
   } Catch {
       gLogMsg "Upload Failed."
       gLogMsg $ERROR[0].Exception
   }
   return $False
}

gLoginSelectSubscription $publishSettingsFilePath $subscriptionName

gChangeToARM

addVMImage $vmImageName $osType $vmLabelImageFamily $recommendedVMSize $VHDFilePath $subscriptionName $groupName $storageAccount $containerName
