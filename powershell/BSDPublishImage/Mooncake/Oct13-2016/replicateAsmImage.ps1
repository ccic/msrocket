
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function replicateVMImage(
   [String] $imageName,
   [String] $offer,
   [String] $sku,
   [String] $version)
{
   $c = New-AzurePlatformComputeImageConfig -Offer $offer -Sku $sku -Version $version
   $azureLoc = @()
   foreach ($i in (get-azurelocation).Name) {
      $azureLoc += $i
   }
   gLogMsg "Set-AzurePlatformVMImage -ImageName $imageName -ReplicaLocations $azureLoc -ComputeImageConfig $c"
   Set-AzurePlatformVMImage -ImageName $imageName -ComputeImageConfig $c -ReplicaLocations $azureLoc
   echo $azureLoc
}

gImportModules

gLogin

replicateVMImage $vmImageName $offer $sku $version
