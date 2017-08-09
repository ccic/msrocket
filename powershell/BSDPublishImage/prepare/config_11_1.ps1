$gRelease      = "11_1"
$gSrcVHDName   = "FreeBSD_11_1_tmpl.vhd"
$gDatestamp    = Get-Date -Format yyyyMMdd
$gTgtVHDName   = "FreeBSD_11_1_" + $gDatestamp + ".vhd"
$gVmName       = "hz_FreeBSD11.1_publish_image" ## VM used to modify image VHD
$gMlx4Config   = $True
