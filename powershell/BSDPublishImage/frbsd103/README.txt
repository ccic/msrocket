This folder stores all scripts for VM image management, including upload VHD, publish image, replicate image, remove image and unreplicate image.

1. Usage for publish image

1) manually modify env_config to specify $vmInageName, $version, $publishedDate, and
$VHDFilePath. For example:
------------------------------------------------
$vmImageName         = "FreeBSD11_0-2017-04-28"
$version             = "11.0.20170428"
$publishedDate       = "04/28/2017"
$VHDFilePath         = "C:\home\Work\Azure\vhd\FreeBSD_11_0_20170428.vhd"
------------------------------------------------
2) .\publishImage.ps1 ## it will upload the VHD to specified storage
container, create VM image and replicate to all data centers.
3) .\getReplicateStatus.ps1 ## it tells you the replication status. Only when
replications on all data centers were 100%, run next command:
4) .\makeImagePublic.ps1  ## it makes the VM image accessable on all data
centers for any users. ## it will not take effect immediately, please use
.\getAzureVMImage.ps1 to check its status
5) .\notShowInGUI.ps1 ## is responsible to hide the original VM image from GUI.

2. Usage for revoking images
If you want to revoke the published images in order to save cost, please run
.\revokeImage.ps1

3. Notes:

env_*.ps1 contains configurable variables, please change them before running any script.

publishImage.ps1 is the entry for publishing any image. It will invoke the following scripts in order:
0. env_asm.ps1            ==> set configurable variables
1. uploadvhdAsm.ps1       ==> create storage account and container, upload VHD
2. addAsmImage.ps1        ==> add Azure VM image
3. updateAsmImage.ps1     ==> update the VM image's label, description, publish date, and recommended size
4. replicateAsmImage.ps1  ==> replicate the VM image to the location of current subscription supported.

revokeImage.ps1 is the entry for unreplicate, remove image

makeImagePublic.ps1 is the final step if VM image passed all test, you'd better make it public and then all subscriptions can see it
