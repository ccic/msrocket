$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function makeImagePublic([String] $imageName)
{
   set-azureplatformvmimage -ImageName $imageName -Permission Public
}

gImportModules
gLogin
makeImagePublic $vmImageName
