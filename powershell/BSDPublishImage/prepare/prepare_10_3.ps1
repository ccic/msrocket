$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\config_10_3.ps1
. $currentWorkingDir\config.ps1

$sts=prepare_vhd $gTgtVHDName
return $sts
