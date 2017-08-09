
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function getReplicationStatus()
{
   Get-AzurePlatformVMImage -ImageName $vmImageName | Select -ExpandProperty "ReplicationProgress"
}

#import-module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Compute\PIR.psd1"
gImportModules

gLogin

getReplicationStatus


