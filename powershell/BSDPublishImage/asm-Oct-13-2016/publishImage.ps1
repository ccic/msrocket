
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. $currentWorkingDir\env_asm.ps1

echo "VM image name: '$vmImageName'"

$ret=.\uploadvhdAsm.ps1
if ($ret[-1] -eq $False) {
  gLogMsg "Stop for error occurs in upload VHD"
  return $False
} else {
  gLogMsg "finish upload VHD"
}

$ret=.\addAsmImage.ps1
if ($ret[-1] -eq $False) {
  gLogMsg "Stop for failing to add asm image"
  return $False
} else {
  gLogMsg "finish add vm image"
}

$ret=.\updateAsmImage.ps1
if ($ret[-1] -eq $False) {
  gLogMsg "Stop for failing to update image"
  return $False
} else {
  gLogMsg "finish update image"
}

.\replicateAsmImage.ps1
if ($? -eq $False) {
  gLogMsg "Stop for failing to replicate image"
  return $False
} else {
  gLogMsg "start replicate image"
}

