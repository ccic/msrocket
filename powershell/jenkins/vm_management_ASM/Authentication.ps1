
##### set the global var: $LogFile, which is used in function gLogMsg #####
#### global variables ####
$global:gAzureStorageType           = "Standard_LRS"
$global:gAzureContainerPermission   = "Blob"
$global:gProjectName                = "rocket"
$global:gStoragePostfix             = "storage"
$global:gContainerPostfix           = "vhds"
$global:gOStype                     = "Linux"

$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($currentScriptName)
$TimeMark = Get-Date -format ss-mm-HH-M-d-yyyy
$global:LogFile = $nameWithoutExt + "-" + $TimeMark + "-log.txt"

##### depends utility functions  #####


##### include the utility functions                                   #####
. $currentWorkingDir\env_asm.ps1

$ret = gLogin
if ($ret -eq $False) {
   return $False
}

$ret = gSetAccountRelatedResource
if ($ret -eq $False) {
   return $False
}
