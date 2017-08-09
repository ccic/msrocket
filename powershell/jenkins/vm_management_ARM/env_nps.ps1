## global variables ##
$global:gAzureStorageType           = "Standard_LRS"
$global:gAzureContainerPermission   = "Blob"
$global:gProjectName                = "rkt"
$global:gResourceGroupPostfix       = "rmrg"
$global:gStoragePostfix             = "rmstor"
$global:gContainerPostfix           = "vhds"
$global:gOStype                     = "Linux"
$global:gPubProfileFileLabel        = "ProfileFile"
#$global:gPubSettingsFileLabel       = "PublishSettingsFile"
#$gSubscriptionName = "OSTC Shanghai Dev"
#$gStorageAccount   = "honzhanstore"
#$gContainerName    = "honzhancontain"
#$gLocation         = "West Central US"


#### utility functions ####
function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   Write-Host $OutputMsg
}

function getAliasFromEmail([String] $email) {
   $alias, $domain = $email -split '@', 2
   $final_alias = $alias.Replace("-","")
   return $final_alias
}

function gLoginSelectSubscription(
  [String] $publishSettingsFilePath,
  [String] $subscriptionName)
{
   Import-AzurePublishSettingsFile -publishsettingsFile $publishSettingsFilePath
   Select-AzureSubscription -Current -SubscriptionName $subscriptionName
}

function gLoginSelectProfile(
  [String] $profileFullPath,
  [String] $subscriptionName)
{
   Select-AzureRmProfile -Path $profileFullPath
   Select-AzureSubscription -Current -SubscriptionName $subscriptionName
}

function get_profile_file()
{
   $global:gProfileFullPath = join-path $ENV:WORKSPACE -childPath $gPubProfileFileLabel
}

function extract_subname_from_profile([String]$profilePath)
{
   $json = Get-Content $profilePath | out-string | convertfrom-json
   return $json.Context.Subscription.Name
}

function extract_subid_from_profile([String]$profilePath)
{
   $json = Get-Content $profilePath | out-string | convertfrom-json
   return $json.Context.Subscription.Id
}

function gLogin()
{
   get_profile_file
   $subName = extract_subname_from_profile $gProfileFullPath
   gLogMsg "use gLoginSelectProfile"
   gLoginSelectProfile $gProfileFullPath $subName | Out-Null
   return $True
}

function gValidateVHDFilePath(
   [String] $VHDFilePath)
{
   if (!(test-path $VHDFilePath -PathType Leaf)) {
       gLogMsg "VHD file $VHDFilePath is not existed!"
       return $false
   }
   return $True
}

function get_publish_settings_file()
{
   $global:gPublishSettingsFilePath = join-path $ENV:WORKSPACE -childPath $gPubSettingsFileLabel
}

function get_azure_location()
{
   $global:gAzureVMLocation = $ENV:Location
}

function get_vhd_file_location()
{
   $global:gVHDFilePath = $ENV:VHDFilePath
}

function gSetAccountRelatedResource()
{
   $global:gUserEmail = (get-azureaccount|where-object {$_.type -like "user"}).Id
   $global:gSubscriptionId = extract_subid_from_profile $gProfileFullPath
   $global:gSubscriptionName = extract_subname_from_profile $gProfileFullPath
   $global:gAlias = getAliasFromEmail $gUserEmail
   
   $global:AzureStorageType         = $ENV:VMStorageType
   if ($AzureStorageType -match "Premium") {
       ## premium storage only support private mode
       $global:gAzureContainerPermission = "Off"
   } else {
       $global:gAzureContainerPermission = "Blob"
   }
   get_azure_location

   $normal_loc = $gAzureVMLocation -replace '\s', '' ## remove ws
   $normal_loc = $normal_loc.ToLower()               ## to lowercase

   $global:gStorageAccount   = $gAlias + $gProjectName + $normal_loc + $gStoragePostfix
   if ($gStorageAccount -gt 24) {
      # Storage account name must be between 3 and 24 characters in length
      # and use numbers and lower-case letters only.
      $global:gStorageAccount = $gStorageAccount.Substring(0, 24)
   }
   $global:gStorageContainer = $gAlias + $gProjectName + $normal_loc + $gContainerPostfix

   $global:gResourceGroupName = $gAlias + $gProjectName + $normal_loc + $gResourceGroupPostfix
   $global:gLoginUser        = $ENV:LoginUser
   $global:gLoginPassword    = $ENV:LoginPassword

   $global:gVMName           = $ENV:VMName
   $global:gVMSize           = $ENV:VMSize
   
   get_vhd_file_location

   gLogMsg "Azure login user email: '$gUserEmail'"
   gLogMsg "Azure login user alias: '$gAlias'"
   gLogMsg "Subscription:           '$gSubscriptionName'"
   gLogMsg "SubscriptionId:         '$gSubscriptionId'"
   gLogMsg "Storage account:        '$gStorageAccount'"
   gLogMsg "Storage container:      '$gStorageContainer'"
   gLogMsg "Storage container perm: '$gAzureContainerPermission'"
   gLogMsg "VM location:            '$gAzureVMLocation'"
   gLogMsg "VHD file path:          '$gVHDFilePath'"
   gLogMsg "Resource group name:    '$gResourceGroupName'"
   gLogMsg "Login user name:        '$gLoginUser'"
   gLogMsg "Login user password:    '$gLoginPassword'"
   gLogMsg "VM name:                '$gVMName'"
   gLogMsg "VM size:                '$gVMSize'"


   $ret = gValidateVHDFilePath $gVHDFilePath
   if ($ret -eq $False) {
      return $False
   }

   return $True
}

function create_res_grp_if_notexist(
   [String]$Rsgrp,
   [String]$loc)
{
   $rg = Get-AzureRmResourceGroup -Name $Rsgrp -Location $loc
   if ($? -eq $True) {
      gLogMsg "Resource Grp '$Rsgrp' exists on '$loc'"
      return $True
   } else {
      New-AzureRmResourceGroup -Name $Rsgrp -Location $loc
      if ($? -eq $True) {
         gLogMsg "Successfully create resource group '$Rsgrp' on '$loc'"
         return $True
      } else {
         return $False
      }
   }
   return $False
}

function create_storage_ctx(
   [String] $Rsgrp,
   [String] $StorageAccount)
{
   $StorageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $Rsgrp -AccountName $StorageAccount).Value[0]
   if ($? -eq $False) {
       gLogMsg "Fail to get Azure storage key"
       return $False
   }
   gLogMsg "Storage key1: '$Storagekey'"
   $sourceContext = New-AzureStorageContext -StorageAccountName $storageAccount `
                                            -StorageAccountKey $StorageKey 
   return $sourceContext
}

function create_storage_account_if_notexist(
   [String]$SubName,
   [String]$Rsgrp,
   [String]$StorageAccount,
   [String]$StorageAccountType,
   [String]$Loc)
{
   Get-AzureRmStorageAccount -ResourceGroupName $Rsgrp -Name $StorageAccount
   if ($? -eq $True) {
      gLogMsg "Storage account '$StorageAccount' exists"
   } else {
      New-AzureRmStorageAccount -ResourceGroupName $Rsgrp -Name $StorageAccount `
                                -Location $Loc -SkuName $StorageAccountType
      if ($? -eq $False) {
         gLogMsg "Fail to create storage account '$StorageAccount' on '$Loc'"
         return $False
      } else {
         gLogMsg "Successfully create storage account '$StorageAccount' on '$Loc'"
      }
   }

   $sourceContext = create_storage_ctx $Rsgrp $StorageAccount
   if ($sourceContext -eq $Null) {
      return $False
   }
   Set-AzureSubscription -SubscriptionName $SubName `
                         -CurrentStorageAccountName $StorageAccount `
                         -context $sourceContext
   return $?
}

function create_container_if_notexist(
   [String] $Rsgrp,
   [String] $StorageAccount,
   [String] $ContainerName,
   [String] $ContainerPermission)
{
   $sourceContext = create_storage_ctx $Rsgrp $StorageAccount
   if ($sourceContext -eq $Null) {
      return $False
   }
   $container = get-azurestoragecontainer -Name $containerName -context $sourceContext 
   if ($? -eq $False) {
       gLogMsg "New-AzureStorageContainer -Name $containerName -Permission $containerPermission"
       New-AzureStorageContainer -Name $ContainerName -Permission $ContainerPermission -context $sourceContext
       if ($? -eq $True) {
          gLogMsg "Successfully create storage container"
          return $True
       } else {
          gLogMsg "Fail to create storage container"
          return $False
       }
   } else {
       gLogMsg "Container '$ContainerName' already existed!"
       return $True
   } 
}

function getVHDURL(
   [String]$VHDFile,
   [String]$SubscriptionId,
   [String]$ResourceGroupName,
   [String]$StorageAccountName,
   [String]$ContainerName)
{
   $FileName = [IO.Path]::GetFileNameWithoutExtension($VHDFile)
   $BlobFileName = "{0}.vhd" -f $FileName
   # Prepare subscription and storage account
   Try
   {

       Select-AzureRmSubscription -SubscriptionId  $SubscriptionId | out-Null
       Set-AzureRmCurrentStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName | out-Null

       $sourceContext = create_storage_ctx $ResourceGroupName $StorageAccountName
       if ($sourceContext -eq $Null) {
           gLogMsg "Fail to create storage context"
           return $Null
       }
       $blobContainer = Get-AzureStorageContainer -Name $ContainerName -Context $sourceContext

       # Build path for VHD BlobPage file uploading
       $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName
       gLogMsg "VHDURL: $mediaLocation"
       return $mediaLocation
   }
   Catch
   {
       gLogMsg "Upload VHD Image Failed."
       gLogMsg $ERROR[0].Exception
       return $Null
   }
   return $Null
}

function uploadVhd(
   [String]$VHDFile,
   [String]$SubscriptionId,
   [String]$ResourceGroupName,
   [String]$StorageAccountName,
   [String]$ContainerName)
{
   # Blob has 1G on size limitation, related byte number is used below
   $GByteSize = 1073741824

   $mediaLocation = getVHDURL $VHDFile $SubscriptionId $ResourceGroupName $StorageAccountName $ContainerName
   if ($mediaLocation -eq $Null) {
       gLogMsg "Fail to generate VHD URL"
       return $False
   }
   gLogMsg "The upload destination: $mediaLocation"
   Try
   {
	# Upload VHD Image
	Add-AzureRmVhd -ResourceGroupName $ResourceGroupName -LocalFilePath $VHDFile `
                       -Destination $mediaLocation -NumberOfUploaderThreads 64 -OverWrite
	gLogMsg "'$VHDFile' has been successfully uploaded to '$mediaLocation'."
   }
   Catch
   {
	gLogMsg "Upload VHD Image Failed."
	gLogMsg $ERROR[0].Exception
        return $False
   }
   return $True
}

function createNetwork(
   [String]$ResourceGroupName,
   [String]$VMName,
   [String]$location)
{
   # Create a virtual network
   # step 1: Create the subnet.
   $subnetName = $VMName + "subnet"
   $singleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix 10.0.0.0/24

   # step 2: Create the virtual network.
   $vnetName = $VMName + "vnet"
   $vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroupName
   if ($? -eq $False) {
      $vnet = New-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroupName `
                                        -Location $location -AddressPrefix 10.0.0.0/16 `
                                        -Subnet $singleSubnet
      gLogMsg "Create virtual network '$vnetName' on '$ResourceGroupName' and '$location'"
   }
   # Create a public IP address and network interface
   $ipName = $VMName + "pip"
   $pip = Get-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $ResourceGroupName
   if ($? -eq $False) {
      $pip = New-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $ResourceGroupName `
                                        -Location $location -AllocationMethod Dynamic
      gLogMsg "Create public IP addr '$ipName' on '$ResourceGroupName' and '$location'"
   }
   $nicName = $VMName + "nic"
   $nic = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName
   if ($? -eq $False) {
      $nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName `
                                         -Location $location -SubnetId $vnet.Subnets[0].Id `
                                         -PublicIpAddressId $pip.Id
      gLogMsg "Create network interface '$nicName' on '$ResourceGroupName' and '$location'"
   }
   return $nic
}

function createVM(
   [String]$VHDFile,
   [String]$SubscriptionId,
   [String]$ResourceGroupName,
   [String]$StorageAccountName,
   [String]$ContainerName,
   [String]$Location,
   [String]$VMName,
   [String]$VMSize,
   [String]$username,
   [String]$passwd)
{
   
   $Credential = New-Object PSCredential $username, ($passwd | ConvertTo-SecureString -AsPlainText -Force)
   $storageAcc = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName

   # Set the VM name and size
   $vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
   gLogMsg "VMName: $VMName, VMSize: $VMSize"

   # use VHD file name as computer name
   $osDiskName = $VMName #[IO.Path]::GetFileNameWithoutExtension($VHDFile)
   #Set the Windows operating system configuration and add the NIC
   $vm = Set-AzureRmVMOperatingSystem -VM $vmConfig -ComputerName $VMName -Linux -Credential $Credential
   gLogMsg "ComputerName: $VMName"
   $nic = createNetwork $ResourceGroupName $VMName $Location
   $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

   # Create the OS disk URI
   $sourceContext = create_storage_ctx $ResourceGroupName $StorageAccountName
   if ($sourceContext -eq $Null) {
       gLogMsg "Fail to create storage context"
       return $Null
   }
   $blobContainer = Get-AzureStorageContainer -Name $ContainerName -Context $sourceContext
   $osDiskUri = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $VMName + ".vhd"
   #$osDiskUri = "{0}$ContainerName/{1}.vhd" -f $storageAcc.PrimaryEndpoints.Blob.ToString(), $VMName.ToLower()
   gLogMsg "VM's disk URI: $osDiskUri"
   # Get source image URI
   $imageURI = getVHDURL $VHDFile $SubscriptionId $ResourceGroupName $StorageAccountName $ContainerName
   if ($imageURI -eq $Null) {
       gLogMsg "Fail to generate VHD URL"
       return $False
   }
   gLogMsg "ImageURI: $imageURI"
   # Configure the OS disk to be created from the existing VHD image (-CreateOption fromImage).
   $vm = Set-AzureRmVMOSDisk -VM $vm -Name $osDiskName `
                             -CreateOption fromImage -SourceImageUri $imageURI -Linux `
                             -VhdUri $osDiskUri

   #$vm.OSProfile = $null
   # Create the new VM
   gLogMsg "Begin to create the vm named $VMName with $VMSize in $ResourceGroupName in $location"
   New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $location -VM $vm -Verbose
   return $True
}
