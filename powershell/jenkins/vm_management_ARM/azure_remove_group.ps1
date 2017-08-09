$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)
$startDateString = Get-Date -Format yyyy-MM-dd-HH-mm-ss

$LogFile = $nameWithoutExt + "-" + $startDateString + "-log.txt"

function log_msg([String] $msg) {
   echo $msg >> $LogFile
}

$Env:PublishSettingsFile > $LogFile
$Env:GroupAccount >> $LogFile
$ENV:WORKSPACE >> $LogFile

#### check publish setting files, login through it, and switch to ARM mode ####
$PublishSettingsFilePath = join-path $ENV:WORKSPACE -childPath "PublishSettingsFile"
if (!(test-path $PublishSettingsFilePath)) {
   write-host -f Red "Cannot find the uploaded publish settings file" >> $LogFile
   return $false
}
$publishConfig = [xml] (Get-Content -Path $PublishSettingsFilePath)

$subscription_name = ($publishConfig.PublishData.PublishProfile.Subscription |select Name).Name

Import-AzurePublishSettingsFile -PublishSettingsFile $PublishSettingsFilePath

if ($? -eq $False) {
   log_msg "Fail to import the azure publish setting file"
   return $false
}

Switch-AzureMode -Name AzureResourceManager

log_msg "Get-AzureResourceGroup -Name $Env:GroupAccount"
Get-AzureResourceGroup -Name $Env:GroupAccount
if ($? -eq $True) {
    log_msg "Get-AzureResourceGroup -Name $Env:GroupAccount | Remove-AzureResourceGroup -Force"
    Get-AzureResourceGroup -Name $Env:GroupAccount | Remove-AzureResourceGroup -Force
    Get-AzureResourceGroup -Name $Env:GroupAccount
    if ($? -eq $False) {
        log_msg "Successfully remove $Env:GroupAccount"
        return $True
    }
} else {
    log_msg "$Env:GroupAccount has already been removed"
    return $True
}
