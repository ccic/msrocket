$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function updateVMImageNotShowInGUI(
   [String] $imageName,
   [String] $labelImgFamily,
   [String] $subscriptionName)
{
   Try
   {
       # Prepare subscription and storage account
       Select-AzureSubscription -Current -SubscriptionName $subscriptionName

       gLogMsg "Update-AzureVMImage -ImageName $imageName -Label $labelImgFamily -DontShowInGui"
       Update-AzureVMImage -ImageName $imageName -Label $labelImgFamily -DontShowInGui
   } Catch {
       gLogMsg "Upload Failed."
       gLogMsg $ERROR[0].Exception
   }
   return $False
}

gLogin

updateVMImageNotShowInGUI $vmImageName $vmLabelImageFamily $subscriptionName
