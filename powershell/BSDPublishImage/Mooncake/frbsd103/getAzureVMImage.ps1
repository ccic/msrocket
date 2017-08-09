$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

function getAzureVMImage([String] $imagePattern)
{
   #(get-azurevmimage|where {$_.ImageName -like $imagePattern}).ImageName
   get-azurevmimage|where {$_.ImageName -like $imagePattern}
}

gLogin

getAzureVMImage "*FreeBSD10_3*"
