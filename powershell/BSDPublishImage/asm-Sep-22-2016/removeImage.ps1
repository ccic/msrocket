
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function removeVMImage([String] $imageName) 
{
   $vmImage = Get-AzureVMImage -ImageName $imageName
   if ($vmImage -ne $null) {
      glogMsg "$imageName is found"
      Remove-AzureVMImage -ImageName $imageName -DeleteVHD
      $vmImage = Get-AzureVMImage -ImageName $imageName   
      if ($vmImage -eq $null) {
         glogMsg "$imageName is removed"
      } else {
         glogMsg "Failed to remove $imageName"
      }
   }
}

gLogin

removeVMImage $vmImageName
