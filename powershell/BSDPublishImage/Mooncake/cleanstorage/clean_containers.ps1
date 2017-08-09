Param
(
   [Parameter(Mandatory=$True)]
   [String] $deleteContainer
)

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function list_all_containers(
   [String] $subscriptionName,
   [String] $storageAccount,
   [bool] $delete)
{
   Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
   Select-AzureSubscription -SubscriptionName $subscriptionName
   $StorageKey = (Get-AzureStorageKey -StorageAccountName $storageAccount).Primary
   if ($? -eq $False) {
           return $False
   }
   gLogMsg "Storage primary key: $StorageKey"
   $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $StorageKey

   $containers = get-azurestoragecontainer -Context $sourceContext -Name "bootdiag*"
   foreach ($cont in $containers) {
      Write-Output ${cont}.Name
      if ($delete) {
          remove-azurestoragecontainer -Name ${cont}.Name -Force
      }
   }
   return $True
}

gLogin

gLogMsg "list_all_containers $subscriptionName $storageAccount"
$delete = $deleteContainer -eq "1"
list_all_containers $subscriptionName $storageAccount $delete
