param(
  [Parameter(Mandatory=$True)]
  [bool]$createResource = $False,

  [Parameter(Mandatory=$True)]
  [bool]$uploadVHD = $False,

  [Parameter(Mandatory=$True)]
  [bool]$createVM = $False
)

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env.ps1

<#
$ProjectName = "rocket"
$AzureGroupAccount = "honzhan"
$AzureStorageAccount = "honzhanstorage"
$AzureStorageContainer = "honzhancontainer"
$AzureVMLocation = "East Asia"
$AzureStorageType = "Standard_LRS"
$AzureContainerPermission = "Blob"
#>

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)
$TimeMark = Get-Date -format ss-mm-HH-M-d-yyyy
$global:LogFile = $nameWithoutExt + "-" + $TimeMark + "-log.txt"

function create_group_account_if_not_exist([String] $resGrpName, [String] $loc) {
   #Set-AzureSubscription -SubscriptionName $global:SubscriptionName
   #Select-AzureSubscription -Current -SubscriptionName $global:SubscriptionName
   $curr_subscription = get_subscription
   if ($curr_subscription -ne $global:SubscriptionName) {
       log_msg "Subscription '$curr_subscription' is not equal to expected '$global:SubscriptionName'"
       return $False
   }
   log_msg "get-azureresourcegroup -Name $resGrpName"
   get-azureresourcegroup -Name $resGrpName
   if ($? -eq $False) {
       New-AzureResourceGroup -Name $resGrpName -Location $loc
       if ($? -eq $False) {
           log_msg "Fail to create resource group '$resGrpName'"
           return $False
       } else {
           log_msg "Successfully create resource group '$resGrpName'"
           return $True
       }
   } else {
       log_msg "Resource group '$resGrpName' already existed"
       return $True
   }
}

function create_storage_account_if_not_exist(
   [String] $resGrpName,
   [String] $expectStorageAccount,
   [String] $loc,
   [String] $type) {
   #Set-AzureSubscription -SubscriptionName $global:SubscriptionName
   $curr_subscription = get_subscription
   if ($curr_subscription -ne $global:SubscriptionName) {
       log_msg "Subscription '$curr_subscription' is not equal to expected '$global:SubscriptionName'"
       return $False
   }
   log_msg "Get-AzureStorageAccount -ResourceGroupName $resGrpName -AccountName $expectStorageAccount"
   Get-AzureStorageAccount -ResourceGroupName $resGrpName -AccountName $expectStorageAccount
   if ($? -eq $False) {
       log_msg "New-AzureStorageAccount -ResourceGroupName $resGrpName -AccountName $expectStorageAccount -Location $loc -Type $type"
       New-AzureStorageAccount -ResourceGroupName $resGrpName -AccountName $expectStorageAccount -Location $loc -Type $type
       if ($? -eq $False) {
           log_msg "Fail to create storage account '$expectStorageAccount'"
           return $False
       } else {
           $sleepSec = 2
           $status = (New-AzureStorageAccount -ResourceGroupName $resGrpName `
                               -AccountName $expectStorageAccount `
                               -Location $loc `
                               -Type $type).ProvisioningState
           while ($status -ne "Succeeded") {
              
               log_msg "Sleep for $sleepSec"
               Start-Sleep -s $sleepSec
               $status = (New-AzureStorageAccount -ResourceGroupName $resGrpName `
                               -AccountName $expectStorageAccount `
                               -Location $loc `
                               -Type $type).ProvisioningState
           }
           if ($status -eq "Succeeded") {
               return $True
           } else {
               return $False
	   }
       }
   } else {
       log_msg "Storage account '$expectStorageAccount' already existed"
       return $True
   }
}

function create_container_if_not_exist(
   [String] $resGrpName,
   [String] $storageAccount,
   [String] $containerName,
   [String] $permission) {
   #Set-AzureSubscription -SubscriptionName $global:SubscriptionName
   $curr_subscription = get_subscription
   if ($curr_subscription -ne $global:SubscriptionName) {
       log_msg "Subscription '$curr_subscription' is not equal to expected '$global:SubscriptionName'"
       return $False
   }
   log_msg "Get-AzureStorageAccountKey -ResourceGroupName $resGrpName -Name $storageAccount"
   $storageKey = (Get-AzureStorageAccountKey -ResourceGroupName $resGrpName -Name $storageAccount).Key1
   log_msg "storage key '$storageKey'"
   $storageContext = New-AzureStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $storageKey
   log_msg "Get-AzureStorageContainer -Name $containerName -Context $storageContext"
   $blobContainer = Get-AzureStorageContainer -Name $containerName -Context $storageContext
   if ($? -eq $False) {
      log_msg " New-AzureStorageContainer -Context $storageContext -Permission $permission -Name $containerName"
      New-AzureStorageContainer -Context $storageContext -Permission $permission -Name $containerName
      if ($? -eq $True) {
          log_msg "Successfully create azure storage container"
          return $True
      } else {
          log_msg "Fail to create azure storage container"
          return $False
      }
   } else {
      log_msg "Container is already existed"
      return $True
   }
}

function upload_vhd (
   [String] $VHDFile,
   [String] $SubscriptionName,
   [String] $GroupName,
   [String] $StorageAccountName,
   [String] $ContainerName) {
   # Build DateTime string for blob name generation and operation purpose
   #$startDateString = Get-Date -Format yyyy-MM-dd-HH-mm-ss

   Try
   {
       # build Azure Storage File Name: LocalFileName-yyyy-MM-dd-HH-mm-ss.vhd
       $FileName = [IO.Path]::GetFileNameWithoutExtension($VHDFile)
       $BlobFileName = $FileName + ".vhd"
       #if ($BlobFileName.Length -eq 0) {
       #    $BlobFileName = "{0}-{1}.vhd" -f $FileName, $startDateString
       #}

       # Prepare subscription and storage account
       Set-AzureSubscription -SubscriptionName $SubscriptionName -CurrentStorageAccountName $StorageAccountName
       Select-AzureSubscription -SubscriptionName $SubscriptionName
       $StorageKey = (Get-AzureStorageAccountKey  -StorageAccountName $StorageAccountName -ResourceGroupName $GroupName).Key1
       log_msg "Storage primary key: '$StorageKey'"
       $sourceContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKey
       $blobContainer = Get-AzureStorageContainer -Name $ContainerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName

       Try
       {
           log_msg "Before Add-AzureVhd"
           # Upload VHD Image
           Add-AzureVhd -LocalFilePath $VHDFile -Destination $mediaLocation -NumberOfUploaderThreads 64 -OverWrite  -ResourceGroupName $GroupName
           if ($? -eq $True) {
               log_msg "'$BlobFileName' uploaded success."
               return $True
           } else {
               log_msg "'$BlobFileName' upload failed."
               return $False
           }
       } Catch {
           log_msg "Upload VHD Image Failed."
           log_msg $ERROR[0].Exception
       }
   } Catch {
       log_msg "Upload Failed."
       log_msg $ERROR[0].Exception
   }
   return $False
}

#### dump environment parameters ####
log_env_parameters $LogFile

#### login through publish settings file ####
login_azure 
if ($? -eq $False) {
   log_msg "Fail to login by importing the azure publish setting file"
   return $false
}

####
setup_AzureVM_env

#### check whether VHD file path is correct and file existed ####
if (!(test-path $localVHDFilePath -PathType Leaf)) {
   log_msg "VHD file $localVHDFilePath is invalid"
   return $false
}

#### switch mode to ARM ####
Switch-AzureMode -Name AzureResourceManager

if ($createResource -eq $True) {
   #### check whether the resource group is existed, otherwise create it ####
   $ret = create_group_account_if_not_exist $AzureGroupAccount $AzureVMLocation
   if ($ret -eq $False) {
      return $False
   }

   #### check whether the storage account is existed, otherwise create it ####
   $ret = create_storage_account_if_not_exist $AzureGroupAccount $AzureStorageAccount $AzureVMLocation $AzureStorageType
   if ($ret -eq $False) {
      return $False
   }

   #### check whether the container is existed, otherwise create it ####
   $ret = create_container_if_not_exist $AzureGroupAccount $AzureStorageAccount $AzureStorageContainer $AzureContainerPermission
   if ($ret -eq $False) {
      return $False
   }
}

if ($uploadVHD -eq $True) {
   $ret = upload_vhd $localVHDFilePath $SubscriptionName $AzureGroupAccount $AzureStorageAccount $AzureStorageContainer
   if ($ret -eq $False) {
      return $ret
   }
}

if ($createVM -eq $True) {
   $VHDFileName = [IO.Path]::GetFileNameWithoutExtension($localVHDFilePath)
   $ret = deploy_vm $SubscriptionName $AzureGroupAccount $AzureStorageAccount `
                 $AzureStorageContainer $VHDFileName $AzureVMName $AzureVMSize `
                 $AzureVMLocation $AzureUser $AzurePasswd $AzureVirtualNetworkName
   if ($ret -eq $False) {
      return $ret
   }
}
