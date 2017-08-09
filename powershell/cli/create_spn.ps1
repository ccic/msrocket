$subscription           = "OSTC Shanghai Dev"
$ServicePrincipalName   = "Service Principal for Creating FreeBSD VM"
$SPNPassword            = "ICUI4CU"
$homePageURL            = "http://www.freebsdSPN"
$identitifierURL        = "http://www.freebsdSPN"
$spn                    = "http://www.freebsdSPN"
$roleName               = "Contributor"

function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   echo $OutputMsg
}

function gSetSubscription([String] $subscriptionName) {
   gLogMsg "azure account set $subscriptionName"
   azure account set $subscriptionName
}

function gListDefaultAccount() {
   gLogMsg "azure account list --json|python -c \"import json,sys;obj=json.load(sys.stdin);n=[str(x['name']) for x in obj if x['isDefault']==True ]; print(n);\""
   azure account list --json|python -c "import json,sys;obj=json.load(sys.stdin);n=[str(x['name']) for x in obj if x['isDefault']==True ]; print(n);"
}

function gGetDefaultSubscriptionId() {
   gLogMsg "azure account list --json|python -c \"import json,sys;obj=json.load(sys.stdin);n=[str(x['id']) for x in obj if x['isDefault']==True ]; print(n[0]);\""
   $subscriptionId = azure account list --json|python -c "import json,sys;obj=json.load(sys.stdin);n=[str(x['id']) for x in obj if x['isDefault']==True ]; print(n[0]);"
   return $subscriptionId
}

function gGetTenenatId() {
   gLogMsg "azure account list --json|python -c \"import json,sys;obj=json.load(sys.stdin);n=[str(x['tenantId']) for x in obj if x['isDefault']==True ]; print(n[0]);\""
   $tenenatId = azure account list --json|python -c "import json,sys;obj=json.load(sys.stdin);n=[str(x['tenantId']) for x in obj if x['isDefault']==True ]; print(n[0]);"
   return $tenenatId
}

function gAzureADAppSearch([String] SPN) {
   gLogMsg "azure ad app show --search $SPN --json|python -c \"import json,sys;obj=json.load(sys.stdin);print(len(obj))\""
   $existedSPN = azure ad app show --search $SPN --json|python -c "import json,sys;obj=json.load(sys.stdin);print(len(obj))"
   return $existedSPN
}

function gSwitchToARM() {
   gLogMsg "azure switch to ARM"
   azure config mode arm
}

gSwitchToARM

gSetSubscription $subscription

gListDefaultAccount

$subscriptionId = gGetDefaultSubscriptionId
$tenenatId      = gGetTenenatId
echo $subscriptionId
echo $tenenatId

$existedSPN = gAzureADAppSearch $ServicePrincipalName #azure ad app show --search $ServicePrincipalName --json|python -c "import json,sys;obj=json.load(sys.stdin);print(len(obj))"

if ($existedSPN -eq 0) {
   echo "azure ad app create --name $ServicePrincipalName --password $SPNPassword --home-page $homePageURL --identifier-uris $identitifierURL --json"
   azure ad app create --name $ServicePrincipalName --password $SPNPassword --home-page $homePageURL --identifier-uris $identitifierURL --json 
   $SPNAppId = azure ad app show --search $ServicePrincipalName --json| python -c "import json,sys;obj=json.load(sys.stdin); n=[str(x['appId']) for x in obj];print(n[0]);"
   echo "AppId $SPNAppId"
   azure ad sp create $SPNAppId --json
   azure role assignment create --spn $spn --roleName $roleName --subscription $subscriptionId --json
} else {
   $SPNAppId = azure ad app show --search $ServicePrincipalName --json| python -c "import json,sys;obj=json.load(sys.stdin); n=str(obj[0]['appId']);print(n);"
   echo "azure ad sp create $SPNAppId --json"
   $existedSP = azure ad sp show --spn $spn --json|python -c "import json,sys;obj=json.load(sys.stdin);print(len(obj))"
   if ($existedSP -eq 0) {
      azure ad sp create $SPNAppId --json
   } else {
      echo "Existed SP"
   }
   azure role assignment create --spn $spn --roleName $roleName --subscription $subscriptionId --json
}

gLogMsg "verification: azure login --username $SPNAppId --password $SPNPassword --service-principal --tenant $tenenatId"
