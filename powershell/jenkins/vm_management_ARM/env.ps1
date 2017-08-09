
function log_env_parameters([String] $logFile) {
   $ENV:PublishSettingsFile >  $logFile
   $ENV:VMSize              >> $logFile
   $ENV:VMStorageType       >> $logFile
   $ENV:WORKSPACE           >> $logFile
   $ENV:VHDFilePath         >> $logFile
   $ENV:LoginUser           >> $logFile
   $ENV:LoginPassword       >> $logFile
   $ENV:VMName              >> $logFile
   $ENV:Location            >> $logFile
}

function get_alias_from_email([String] $email) {
   $alias, $domain = $email -split '@', 2
   $final_alias = $alias.Replace("-","")
   return $final_alias
}

function log_msg([String] $msg) {
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   #echo $OutputMsg ## it will interrupt the normal "return"localVHDFilePath
   echo $OutputMsg >> $global:LogFile
}

## this function should be invoked after user login
## setup the global variables
function setup_AzureVM_env() {
   $global:AzureVMLocation          = $ENV:Location
   $global:AzureStorageType         = $ENV:VMStorageType
   if ($AzureStorageType -match "Premium") {
       ## premium storage only support private mode
       $global:AzureContainerPermission = "Off"
   } else {
       $global:AzureContainerPermission = "Blob"
   }
   
   $global:ProjectName              = "rocketrm" ## add "rm" under ARM
   $global:AzureVMSize              = $ENV:VMSize
   $global:AzureVMName              = $ENV:VMName
   $global:localVHDFilePath         = $ENV:VHDFilePath
   $global:AzureUser                = $ENV:LoginUser
   $global:AzurePasswd              = $ENV:LoginPassword

   $userEmail = (get-azureaccount|where-object {$_.type -like "user"}).Id
   $normalAlias = get_alias_from_email $userEmail

   $global:AzureGroupAccount       = $normalAlias + $ProjectName 
   $global:AzureStorageAccount     = $normalAlias + $ProjectName + "storage"
   $global:AzureStorageContainer   = $normalAlias + $ProjectName + "container" #"vhds"
   $global:AzureVirtualNetworkName = $normalAlias + $ProjectName + "-vnet" ## different VMs locate in the same vnet

   log_msg "Container permission $AzureContainerPermission"
   log_msg "Azure group account $AzureGroupAccount"
   log_msg "Azure storage account $AzureStorageAccount"
   log_msg "Azure storage container $AzureStorageContainer"
   log_msg "Azure virtual network $AzureVirtualNetworkName"
}

function get_subscription() {
   $curSubscriptionName = (get-azuresubscription -current).SubscriptionName
   log_msg "current subscription: '$curSubscriptionName'" 
   return $curSubscriptionName
}

#### check whether publish settings file is uploaded and accessable ####
function get_publish_settings_file()
{
   $global:PublishSettingsFilePath = join-path $ENV:WORKSPACE -childPath "PublishSettingsFile"
   if (!(test-path $PublishSettingsFilePath)) {
      log_msg "Cannot find the uploaded publish settings file"
      return $false
   }
   return $true
}

function login_azure()
{
   get_publish_settings_file
   if ($? -eq $False) {
       return $False
   }

   $publishConfig = [xml] (Get-Content -Path $PublishSettingsFilePath)

   $global:SubscriptionName = ($publishConfig.PublishData.PublishProfile.Subscription |select Name).Name
   log_msg "Subscription: $global:SubscriptionName"

   #### login through publish settings file ####
   Import-AzurePublishSettingsFile -PublishSettingsFile $PublishSettingsFilePath
   if ($? -eq $False) {
      log_msg "Fail to import the azure publish setting file"
      return $false
   }
   Select-AzureSubscription -Current -SubscriptionName $global:SubscriptionName
   return $True
}

function deploy_vm (
   [String] $subscriptionName,
   [String] $resGrpName,
   [String] $storageAccount,
   [String] $container,
   [String] $VHDName,
   [String] $VMName,
   [String] $VMSize,
   [String] $location,
   [String] $loginUser,
   [String] $loginPass,
   [String] $virtualNetworkName) {

   ## generate the json configure file in a temporary folder   
   $jsonConfig = @"
{
    "storageAccountName": {
        "value": "$storageAccount"
    },
    "containerName": {
        "value": "$container"
    },
    "imageVHDName": {
        "value": "$VHDName"
    },
    "vmName": {
        "value": "$VMName"
    },
    "virtualNetworkName": {
        "value": "$virtualNetworkName"
    },
    "vmSize": {
        "value": "$VMSize"
    },
    "location": {
        "value": "$location"
    },
    "adminUsername": {
        "value": "$loginUser"
    },
    "adminPassword": {
        "value": "$loginPass"
    },
    "dnsNameForPublicIP": {
        "value": "$VMName"
    }
}
"@
   $timeStamp4Deply = Get-Date -format ss-mm-HH-M-d-yyyy
   $deployJsonFolder = "json-param-" + $timeStamp4Deply
   $deployJsonFolderPath = join-path $ENV:WORKSPACE -childPath $deployJsonFolder
   log_msg "md $deployJsonFolderPath"
   md $deployJsonFolderPath
   if ($? -eq $False) {
       log_msg "Fail to create folder '$deployJsonFolderPath'"
       return $False
   }
   $deployJsonConfigPath = join-path $deployJsonFolderPath -childPath "azuredeploy.parameters.json"
   $jsonConfig > $deployJsonConfigPath
   ## echo the json configure file content
   Get-Content $deployJsonConfigPath

   ## get the azure json parameter temple file
   $azureTmplPath = join-path $currentWorkingDir -childPath "azuredeploy.json"

   Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount
   Select-AzureSubscription -Current -SubscriptionName $subscriptionName

   log_msg "New-AzureResourceGroupDeployment -ResourceGroupName $resGrpName -TemplateParameterFile $deployJsonConfigPath -TemplateFile .\azuredeploy.json -storageAccountNameFromTemplate $storageAccount"
   New-AzureResourceGroupDeployment -ResourceGroupName $resGrpName -TemplateParameterFile $deployJsonConfigPath -TemplateFile $azureTmplPath -storageAccountNameFromTemplate $storageAccount 
   if ($? -eq $True) {
      log_msg "Successfully deploy the storage"
      return $true
   } else {
      log_msg "Fail to deploy the storage"
      return $False
   }
}
