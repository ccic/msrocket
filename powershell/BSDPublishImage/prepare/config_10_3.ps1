$gRelease      = "10_3"
$gSrcVHDName   = "FreeBSD_10_3_tmpl.vhd"
$gDatestamp    = Get-Date -Format yyyyMMdd
$gTgtVHDName   = "FreeBSD_10_3_" + $gDatestamp + ".vhd"
$gVmName       = "hz_FreeBSD10.3_publish_image" ## VM used to modify image VHD
$gMlx4Config   = $False
