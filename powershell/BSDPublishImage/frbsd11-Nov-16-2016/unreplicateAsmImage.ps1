
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function unreplicate([String] $imageName) {
   $vmImage = Get-AzurePlatformVMImage -ImageName $imageName
   if ($vmImage -ne $null) {
      glogMsg "$imageName is found"
      Remove-AzurePlatformVMImage -ImageName $imageName
      $vmImage = Get-AzurePlatformVMImage -ImageName $imageName
      if ($vmImage -eq $null) {
         glogMsg "$imageName is removed"
      } else {
         glogMsg "Failed to remove $imageName"
      }
   }
}

gImportModules

gLogin

unreplicate $vmImageName
