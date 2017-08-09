
$publishSettingsFileName = "OSTC-Shanghai-Dev.publishsettings"
$VMImageNamePostfix      = "FreeBSD11"
$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function get_publish_settings_file()
{
   $global:gPublishSettingsFilePath = join-path $currentWorkingDir -childPath $publishSettingsFileName
}

function get_azure_location()
{
   $global:gAzureVMLocation = "west europe"
}

function get_vhd_file_location()
{
   $global:gVHDFilePath = "\\sh-ostc-th55dup\d$\vhd\hz_BSD11_SSD1.vhd"
}

function get_vm_image_name_postfix()
{
   $global:gVMImageNamePostfix = $VMImageNamePostfix
}
