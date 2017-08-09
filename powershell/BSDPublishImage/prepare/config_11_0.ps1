$gRelease      = "11_0"
$gSrcVHDName   = "FreeBSD_11_0_tmpl.vhd"
$gDatestamp    = Get-Date -Format yyyyMMdd
$gTgtVHDName   = "FreeBSD_11_0_" + $gDatestamp + ".vhd"
$gVmName       = "hz_FreeBSD11.0_publish_image" ## VM used to modify image VHD
$gMlx4Config   = $False
