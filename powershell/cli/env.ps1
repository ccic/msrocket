
$gSubscriptionName = "OSTC Shanghai Dev"

function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   echo $OutputMsg
}

function gLoginOSTCDev() {
   gLogMsg "azure login --username b8a77132-6ee7-481a-8a29-22797c849e1a --password ICUI4CU --service-principal --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47"
   azure login --username b8a77132-6ee7-481a-8a29-22797c849e1a --password ICUI4CU --service-principal --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47
}

function gSetSubscription([String] $subscriptionName) {
   gLogMsg "azure account set $subscriptionName"
   azure account set $subscriptionName
}

function gSwitchToArm() {
   gLogMsg "azure config mode arm"
   azure config mode arm
}

function gGetAzureLocationList() {
   $locationArray = @()
   $parsedJson = azure location list --json|ConvertFrom-Json
   foreach ($line in $parsedJson) {
      echo $line.name
   }
   #$loc = azure location list --json|python -c "import json,sys;obj=json.load(sys.stdin);n=[str(x['name']) for x in obj]; print(list(n));"
   #echo $loc
   #foreach ($i in $loc) {
   #   echo $i
   #}
}
