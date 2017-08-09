<#Param
(
   [Parameter(Mandatory=$True)]
   [String]$gSubName
)
#>

$pwd = Split-Path -Parent $MyInvocation.MyCommand.Definition

function loginCheck()
{
   Try {
      Get-AzureRmContext
   } Catch {
      if ($_ -like "*Login-AzureRmAccount to login*") {
         # for Mooncake: 'Login-AzureRmAccount -EnvironmentName AzureChinaCloud'
         Login-AzureRmAccount
      }
   }
}

function getSubProfile()
{
   #$pwd = Split-Path -Parent $MyInvocation.MyCommand.Definition
   $valid = $False
   loginCheck
   Write-Host "==Dumping the subscriptions ... ==" -foreground Green
   $subs = (Get-AzureRmSubscription).SubscriptionName
   foreach ($i in $subs) {
      Write-Host $i -foreground Yellow
   }
   $SubName = Read-Host - Prompt 'Specify the Subscription Name'
   foreach ($i in $subs) {
      if ($i -eq $SubName) {
          $valid = $True
      }
   }
   $normalFile = $SubName -replace ' ', '_'
   $normalFile = $normalFile + "_profile.json"
   $FilePath = join-path $pwd $normalFile

   if ($valid) {
      Write-Host "Save profile to $FilePath" -foreground Yellow
      Set-AzureRmContext -Subscriptionname $SubName
      Save-AzureRmProfile -path $FilePath
   }
}

getSubProfile
