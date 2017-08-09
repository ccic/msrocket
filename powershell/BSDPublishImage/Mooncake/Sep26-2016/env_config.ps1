$imageTimestamp      = Get-Date -Format yyyy-MM-dd
$imageNameCreate     = "FreeBSD10_3-" + $imageTimestamp
$vmImageName         = "FreeBSD10_3-2016-09-26" #"FreeBSD10_3-2016-05-20" #$imageNameCreate

$version             = "10.3.20160926"
$publishedDate       = "9/26/2016"
$VHDFilePath         = "C:\home\Work\Azure\vhd\FreeBSD_10_3_20160926_errata.vhd"
