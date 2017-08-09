$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function addVMImage(
   [String] $imageName,
   [String] $osType,
   [String] $labelImgFamily,
   [String] $recommendedVMSize,
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
       Select-AzureSubscription -Current -SubscriptionName $subscriptionName
       $StorageKey = (Get-AzureStorageKey -StorageAccountName $stroageAccount).Primary
       if ($? -eq $False) {
           return $False
       }
       gLogMsg "Storage primary key: $StorageKey"
       $sts = Get-AzureVMImage -ImageName $imageName
       if ($sts -eq $null) {
           gLogMsg "Image '$imageName' does not exist and will create it"
           $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey
           $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
           $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName
           gLogMsg "media location: $mediaLocation"

           gLogMsg "Add-AzureVMImage -ImageName $imageName -MediaLocation $mediaLocation -OS $osType -Label $labelImgFamily -RecommendedVMSize $recommendedVMSize"
           Add-AzureVMImage -ImageName $imageName -MediaLocation $mediaLocation -OS $osType -Label $labelImgFamily -RecommendedVMSize $recommendedVMSize
           $sts = Get-AzureVMImage -ImageName $imageName
           if ($sts -eq $null) {
              gLogMsg "Fail to create '$imageName'"
              return $False
           } else {
              gLogMsg "Successfully create '$imageName'"
              return $True
           }
       } else {
           gLogMsg "Image '$imageName' has existed!"
           return $True
       }
   } Catch {
       gLogMsg "Upload Failed."
       gLogMsg $ERROR[0].Exception
   }
   return $False
}

gLogin

addVMImage $vmImageName $osType $vmLabelImageFamily $recommendedVMSize $VHDFilePath $subscriptionName $storageAccount $containerName

