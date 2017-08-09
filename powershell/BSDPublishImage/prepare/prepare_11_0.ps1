$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\config_11_0.ps1
. $currentWorkingDir\config.ps1

$sts=prepare_vhd $gTgtVHDName
return $sts
