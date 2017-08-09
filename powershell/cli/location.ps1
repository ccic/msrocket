. .\env.ps1
$searchVMSize = "Standard_DS14"
function findLocation4GivenVMSize([String] $vmSize)
{
   $parsedJson = azure location list --json|ConvertFrom-Json
   foreach ($line in $parsedJson) {
      #echo $line.name
      $vmSizes4Loc = azure vm sizes -l $line.name --json|ConvertFrom-Json
      foreach ($vms in $vmSizes4Loc) {
         if ($vms.name -eq $vmSize) {
             echo $line.name
             break
         }
      }
   }
}

gLoginOSTCDev

gSwitchToArm

gSetSubscription $gSubscriptionName

findLocation4GivenVMSize $searchVMSize

