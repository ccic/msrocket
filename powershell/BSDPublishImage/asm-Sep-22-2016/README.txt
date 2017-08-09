This folder stores all scripts for VM image management, including upload VHD, publish image, replicate image, remove image and unreplicate image.

env_*.ps1 contains configurable variables, please change them before running any script.

publishImage.ps1 is the entry for publishing any image. It will invoke the following scripts in order:
0. env_asm.ps1            ==> set configurable variables
1. uploadvhdAsm.ps1       ==> create storage account and container, upload VHD
2. addAsmImage.ps1        ==> add Azure VM image
3. updateAsmImage.ps1     ==> update the VM image's label, description, publish date, and recommended size
4. replicateAsmImage.ps1  ==> replicate the VM image to the location of current subscription supported.

revokeImage.ps1 is the entry for unreplicate, remove image

makeImagePublic.ps1 is the final step if VM image passed all test, you'd better make it public and then all subscriptions can see it
