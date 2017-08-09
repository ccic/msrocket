$ret = add-azureaccount
if ($? -eq $False) {
   echo "Fail to login on Azure"
   return $False
} else {
   $ret
   Get-AzurePublishSettingsFile
   return $?
}
