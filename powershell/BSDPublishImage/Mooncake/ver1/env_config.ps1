$imageTimestamp      = Get-Date -Format yyyy-MM-dd
$imageNameCreate     = "FreeBSD10_3-" + $imageTimestamp
$vmImageName         = "FreeBSD10_3-2016-06-02" #"FreeBSD10_3-2016-05-20" #$imageNameCreate

$version             = "10.3.20160602"
$VHDFilePath         = "C:\home\Work\Azure\vhd\FreeBSD_10_3_release_clean_20160602.vhd"
