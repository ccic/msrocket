
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function updateVMImage(
   [String] $imageName,
   [String] $description,
   [String] $labelImgFamily,
   [String] $recommendedVMSize,
   [String] $subscriptionName)
{
   Try
   {
       # Prepare subscription and storage account
       Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
       Select-AzureSubscription -Current -SubscriptionName $subscriptionName

       $publishedDate = Get-Date -Format MM/dd/yyyy
       gLogMsg "Update-AzureVMImage -ImageName $imageName -Label $labelImgFamily -RecommendedVMSize $recommendedVMSize -Description '$description' -PublishedDate $publishedDate" # -Eula $eula "
       Update-AzureVMImage -ImageName $imageName -Label $labelImgFamily `
                           -RecommendedVMSize $recommendedVMSize -Description $description `
                           -PublishedDate $publishedDate #-Eula $eula
   } Catch {
       gLogMsg "Upload Failed."
       gLogMsg $ERROR[0].Exception
   }
   return $False
}

gLogin

updateVMImage $vmImageName $imageDescription $vmLabelImageFamily $recommendedVMSize $subscriptionName

