
$publishSettingsFileLabel = "PublishSettingsFile"

function get_publish_settings_file()
{
   $global:gPublishSettingsFilePath = join-path $ENV:WORKSPACE -childPath $publishSettingsFileLabel
}

function get_azure_location()
{
   $global:gAzureVMLocation = $ENV:Location
}

function get_vhd_file_location()
{
   $global:gVHDFilePath = $ENV:VHDFilePath
}

function get_vm_image_name_postfix()
{
   $global:gVMImageNamePostfix = $ENV:VMImageNamePostfix
}
