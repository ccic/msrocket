$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# release related global variables are defined in other config file #
#$gRelease      = "10_3"
#$gTargetVHD    = "D:\honzhan\ImagePublish\vhd\FreeBSD_10_3_20161109_errata.vhd"
#$gVmName       = "hz_FreeBSD10.3_publish_image" ## VM used to modify image VHD
#$gTgtVHDName is defined in other config file

$gRemoteServer = "sh-ostc-th51dup"              ## host server
$gRelativePath = "\honzhan\ImagePublish\vhd"
$gTargetVHD    = "D:" + $gRelativePath + "\" + $gTgtVHDName
$gScriptPick   = "cherry-pick.sh"
$gScriptCIBrh  = "push-branch-to-remote.sh"
$gBuildWorld   = $True
$gPushCI       = $True
#$gMlx4Config   = $False
$gPPK          = join-path $currentWorkingDir -childPath \..\..\keys\myPrivate.ppk
$gPlink        = join-path $currentWorkingDir -childPath \..\..\bin\plink.exe
$gPscp         = join-path $currentWorkingDir -childPath \..\..\bin\pscp.exe
$gLogDir       = "log"
$gLogFile      = join-path $currentWorkingDir -childPath \$gLogDir\log.txt
$gKernelDir    = "kernel"
$gGitUser      = "azure"
$gRootUser     = "root"
$gMntDir       = "/mnt/image"
$gKernelBldTmp = "/tmp/commits_file.txt"
$gSummaryKrn   = "/tmp/kernel_summary.txt"
$rocketRepo    = "https://github.com/clovertrail/rocket.git"
$rocketDir     = "rocket"
$BISRepo       = "https://github.com/FreeBSDonHyper-V/FreeBSD-Integration-Service.git"
$gBISDir        = "FreeBSD-Integration-Service"

function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   ## create the log folder if it is not existing
   $myLogDir = join-path $currentWorkingDir -childPath $gLogDir
   if (!(Test-Path -Path $myLogDir)) {
       New-Item -ItemType directory -Path $myLogDir
   }
   echo $OutputMsg >> $gLogFile
}

function GetIPv4ViaHyperV([String] $vmName, [String] $server)
{
    <#
    .Synopsis
        Use the Hyper-V network cmdlets to retrieve a VMs IPv4 address.
    .Description
        Look at the IP addresses on each NIC the VM has.  For each
        address, see if it in IPv4 address and then see if it is
        reachable via a ping.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter server
        Name of the server hosting the VM
    .Example
        GetIpv4ViaHyperV $testVMName $serverName
    #>

    $vm = Get-VM -Name $vmName -ComputerName $server -ErrorAction SilentlyContinue
    if (-not $vm)
    {
        Write-Error -Message "GetIPv4ViaHyperV: Unable to create VM object for VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    $networkAdapters = $vm.NetworkAdapters
    if (-not $networkAdapters)
    {
        Write-Error -Message "GetIPv4ViaHyperV: No network adapters found on VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    foreach ($nic in $networkAdapters)
    {
        $ipAddresses = $nic.IPAddresses
        if (-not $ipAddresses)
        {
            Continue
        }

        foreach ($address in $ipAddresses)
        {
            # Ignore address if it is not an IPv4 address
            $addr = [IPAddress] $address
            if ($addr.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork)
            {
                Continue
            }

            # Ignore address if it a loopback address or an invalide address
            if(($address.StartsWith("127.") -eq $True ) -or ($address.StartsWith("0.")) -eq $True)
            {
                Continue
            }

            # See if it is an address we can access
            $ping = New-Object System.Net.NetworkInformation.Ping
            $sts = $ping.Send($address)
            if ($sts -and $sts.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            {
                return $address
            }
        }
    }

    Write-Error -Message "GetIPv4ViaHyperV: No IPv4 address found on any NICs for VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $null
}

function gRemoteExe([String] $vmIP,
                    [String] $user,
                    [String] $exeCmd) {
    $cmdExpr = "echo y|$gPlink -i $gPPK $user@$vmIP `"$exeCmd`""
    gLogMsg "$cmdExpr"
    $ret = Invoke-Expression $cmdExpr
    return "$ret"
}

function gRemoteCopy([String] $vmIP,
                     [String] $user,
                     [String] $srcFilePath,
                     [String] $dstFilePath) {
    $cmdExpr = "echo y|$gPscp -i $gPPK ${user}@${vmIP}:$srcFilePath $dstFilePath"
    gLogMsg "$cmdExpr"
    $ret = Invoke-Expression $cmdExpr
    return "$ret"
}

function gCopy2Remote([String] $vmIP,
                     [String] $user,
                     [String] $srcFilePath,
                     [String] $dstFilePath) {
    $cmdExpr = "$gPscp -i $gPPK $srcFilePath ${user}@${vmIP}:$dstFilePath"
    gLogMsg "$cmdExpr"
    $ret = Invoke-Expression $cmdExpr
    return "$ret"
}

function gStartVM([String] $vmName,
                  [String] $server) {
   $runState = "Running"
   gLogMsg "(get-vm -computername $server|where {`$`_.Name -like $vmName}).State"
   $vmState = (get-vm -computername $server|where {$_.Name -like "$vmName"}).State
   if ($vmState -eq $runState) {
      gLogMsg "VM '$vmName' on '$server' is running"
      return $True
   } elseif ($vmState -eq "Off") {
        start-vm -Name $vmName -Computer $server
        if ($? -eq $True) {
            $timeout = 100
            $i = 1
            do {
               gLogMsg "waiting for VM boot ($i)s ..."
               Start-Sleep -Seconds 1
               $isIPReady = GetIPv4ViaHyperV $gVmName $gRemoteServer
               $i = $i + 1
            } while ($i -le $timeout -and !$isIPReady);
            if ($isIPReady) {
                $ret = $True
                gLogMsg "Successfully start $vmName"
            } else {
                $ret = $False
                gLogMsg "Fail to start the $vmName in $timeout limit"
            }
        } else {
            $ret = $False
            gLogMsg "Fail to start $vmName"
        }
        return $ret
   } elseif ($vmState -eq $null) {
        gLogMsg "Fail to start the VM '$vmName'"
        return $False
   }
}

function gAttachSCSIVHDLoc([String] $vmName,
                           [String] $server,
                           [String] $vhdPath,
                           [String] $ctrNo,
                           [String] $ctrLoc)
{
   gLogMsg "Add-VMHardDiskDrive -VMName $vmName -ControllerType $ControllerType -ControllerNumber $ctrNo -ControllerLocation $ctrLoc -ComputerName $server -Path $vhdPath"
   Add-VMHardDiskDrive -VMName $vmName -ControllerType $ControllerType -ControllerNumber $ctrNo -ControllerLocation $ctrLoc -ComputerName $server -Path $vhdPath
   return $?
}

function gDetachSCSIVHDLoc([String] $vmName,
                           [String] $server,
                           [String] $ctrNo,
                           [String] $ctrLoc)
{
   $ControllerType = "SCSI"
   gLogMsg "remove-vmharddiskdrive -VMName $vmName -ControllerType $ControllerType -ControllerNumber $ctrNo -ControllerLocation $ctrLoc -ComputerName $server"
   remove-vmharddiskdrive -VMName $vmName -ControllerType $ControllerType -ControllerNumber $ctrNo -ControllerLocation $ctrLoc -ComputerName $server
   return $?
}

function gDetachSCSIVHD([String] $vmName,
                        [String] $server)
{
   gDetachSCSIVHDLoc $vmName $server 0 0
   return $?
}

function gAttachSCSIVHD([String] $vmName,
                        [String] $server,
                        [String] $vhdPath,
                        [bool] $force)
{
   $ControllerType = "SCSI"
   gLogMsg "(Get-VMHardDiskDrive -VMName $vmName -ComputerName $server|where {$_.ControllerType -like $ControllerType}).Path"
   $curSCSIvhdPath = (Get-VMHardDiskDrive -VMName $vmName -ComputerName $server|where {$_.ControllerType -like $ControllerType}).Path
   if ($curSCSIvhdPath -eq $null) {
       $ret = gAttachSCSIVHDLoc $vmName $server $vhdPath 0 0
       if ($ret -eq $True) {
          gLogMsg "Successfully attach VHD from host side"
          return $True
       } else {
          gLogMsg "Fail to attach VHD from host side"
          return $False
       }
   } else {
       gLogMsg "'$vhdPath' has already been attached"
       if ($force) {
          gLogMsg "Re-attach the VHD"
          gDetachSCSIVHD $vmName $server
          gAttachSCSIVHDLoc $vmName $server $vhdPath 0 0
          if ($? -eq $True) {
             gLogMsg "Successfully attach VHD from host side"
             return $True
          } else {
             return $False
          }
       } else {
          gLogMsg "Do nothing since vhd is attached"
       }
       return $True
   }
}

function gIsDiskAttachedOnVM([String] $vmIP)
{
   $MsftVHD = "Msft\ Virtual\ Disk"
   $ret = gRemoteExe $vmIP "root" "camcontrol devlist|grep $MsftVHD|grep 'da1'"
   if ($ret -ne $null) {
      return $True
   }
   return $False
}

function attach_vhd_if_vhd_not_attached([String] $vmIP) {
  $diskHasAttached = $False
  $ret = gAttachSCSIVHD $gVmName $gRemoteServer $gTargetVHD $False
  if ($ret) {
     $ret = gIsDiskAttachedOnVM $vmIP
     if ($ret) {
        $diskHasAttached = $True
        gLogMsg "From VM side, the disk is attached"
     }
  }
  return $diskHasAttached
}

function attach_vhd([String] $vmIP) {
  $diskHasAttached = $False
  $ret = gAttachSCSIVHD $gVmName $gRemoteServer $gTargetVHD $True
  if ($ret) {
     $ret = gIsDiskAttachedOnVM $vmIP
     if ($ret) {
        $diskHasAttached = $True
        gLogMsg "From VM side, the disk is attached"
     }
  }
  return $diskHasAttached
}

function detach_vhd_if_attached([String] $vmIP) {
  $ret = gDetachSCSIVHD $gVmName $gRemoteServer
  if ($ret) {
     $ret = gIsDiskAttachedOnVM $vmIP
     if (!$ret) {
        gLogMsg "Fail to detach the VHD"
        return $False
     } else {
        gLogMsg "Successfully detach the VHD"
        return $True
     }
  } else {
     gLogMsg "Fail to detach the VHD"
     return $False
  }
}

function mount_image_if_not_mounted([String] $vmIP) {
  $imageHasMounted = $False
  $result = gRemoteExe $vmIP $gRootUser "[ -e $gMntDir ] && echo 'Ok' || echo 'Notok'"
  gLogMsg $result
  if ($result -eq 'Notok') {
      gLogMsg "create $gMntDir"
      gRemoteExe $vmIP $gRootUser "mkdir $gMntDir"
  }
  $result = gRemoteExe $vmIP $gRootUser "[ -e $gMntDir ] && echo 'Ok' || echo 'Notok'"
  if ($result -eq 'Ok') {
     $result = gRemoteExe $vmIP $gRootUser "mount|grep da1p2 > /dev/null && echo 'mounted' || echo 'umounted'"
     if ($result -like 'umounted') {
        gRemoteExe $vmIP $gRootUser "mount /dev/da1p2 $gMntDir; echo `$`?"
        $result = gRemoteExe $vmIP $gRootUser "mount|grep da1p2 > /dev/null && echo 'mounted' || echo 'umounted'"
        if ($result -like 'mounted') {
           $imageHasMounted = $True
        }
     } else {
        gLogMsg $result
        gLogMsg "/dev/da1p2 has already been mounted"
        $imageHasMounted = $True
     }
  } else {
     gLogMsg "Fail to create $gMntDir"
  }
  return $imageHasMounted
}

function umount_image([String] $vmIP) {
  gRemoteExe $vmIP $gRootUser "umount $gMntDir"
  $result = gRemoteExe $vmIP $gRootUser "mount|grep da1p2 > /dev/null && echo 'mounted' || echo 'umounted'"
  echo $result
  if ($result -like 'mounted') {
     gLogMsg "Fail to umount $gMntDir"
     return $False
  } else {
     gLogMsg "Successfully umount $gMntDir"
     return $True
  }
}

function prepare_mlx4_before_build([String] $vmIP)
{
   $MakeConf = "/etc/make.conf"
   gLogMsg ""
   $rs = gRemoteExe $vmIP $gGitUser "[ -e $MakeConf ] && echo 'Ok' || echo 'Notok'"
   if ($rs -ne 'Ok') {
      gLogMsg "'$MakeConf' does not exist and need to manually create it"
      gRemoteExe $vmIP $gRootUser "echo 'MK_OFED=yes' > $MakeConf"
   }
   # modify GENEIC to include mlx4
   gLogMsg "gRemoteExe $vmIP $gGitUser 'cd $gBISDir; echo 'options COMPAT_LINUXKPI' >> sys/amd64/conf/GENERIC"
   gRemoteExe $vmIP $gGitUser "cd $gBISDir; echo 'options COMPAT_LINUXKPI' >> sys/amd64/conf/GENERIC"
   return $True
}

function prepare_build([String] $vmIP)
{
   $cherry_ci_file  = "commit_file.txt"
   $summary_ci_file = "summary_ci.txt"
   gLogMsg "Check $gBISDir"
   $result = gRemoteExe $vmIP $gGitUser "cd /home/$gGitUser/; [ -e $gBISDir ] && echo 'Ok' || echo 'Notok'"
   if ($result -ne 'Ok') {
       ## checkout the BIS source code
       gLogMsg "checkout the BIS source code"
       gRemoteExe $vmIP $gGitUser "git clone $BISRepo"
   }
   gLogMsg "Check shell script root $rocketDir"
   $result = gRemoteExe $vmIP $gGitUser "cd /home/$gGitUser/; [ -e $rocketDir ] && echo 'Ok' || echo 'Notok'"
   if ($result -ne 'Ok') {
      ## checkout the script source code
      gLogMsg "checkout the rocket scripts"
      gRemoteExe $vmIP $gGitUser "git clone $rocketRepo"
   }

   gLogMsg "gRemoteExe $vmIP $gGitUser 'cd $rocketDir; git pull'"
   gRemoteExe $vmIP $gGitUser "cd $rocketDir; git pull"
   gLogMsg "gRemoteExe $vmIP $gGitUser 'cd $gBISDir; sh ../$rocketDir/shell/builderrata/$gScriptPick $gRelease $gKernelBldTmp $gSummaryKrn'"
   gRemoteExe $vmIP $gGitUser "cd $gBISDir; sh ../$rocketDir/shell/builderrata/$gScriptPick $gRelease $gKernelBldTmp $gSummaryKrn"
   
   gLogMsg "gRemoteCopy $vmIP $gGitUser $gKernelBldTmp $gLogDir/$cherry_ci_file"
   gRemoteCopy $vmIP $gGitUser $gKernelBldTmp $gLogDir/$cherry_ci_file
   gLogMsg "gRemoteCopy $vmIP $gGitUser $gSummaryKrn $gLogDir/$summary_ci_file"
   gRemoteCopy $vmIP $gGitUser $gSummaryKrn $gLogDir/$summary_ci_file
   $realMergeCount = gRemoteExe $vmIP $gGitUser "cd $gBISDir; git status | grep 'Your branch is' | sed -r 's/.*([0-9]+)\ commits\./\1/'"
   $singleMergeCount = gRemoteExe $vmIP $gGitUser "cd $gBISDir; git status | grep 'Your branch is' | sed -r 's/.*([0-9]+)\ commit\./\1/'"
   gLogMsg "Merged count: '$realMergeCount' or '$singleMergeCount'"
   if ($realMergeCount -eq $null) {
      return $False
   }
   $expectedMergeCount = (get-content $gLogDir/$cherry_ci_file | measure-object -Line).Lines
   gLogMsg "Expected merge count: $expectedMergeCount"
   if ($expectedMergeCount -ne 0 -and
       $realMergeCount -ne $expectedMergeCount -and
       $singleMergeCount -ne $expectedMergeCount) {
      gLogMsg "git cherry-pick failed!"
      return $False
   }
   return $True
}

function build_world([String] $vmIP)
{
   $build_world_log  = "build_world.log"
   $install_log      = "install.log"
   gLogMsg "gRemoteExe $vmIP $gRootUser 'cd /home/$gGitUser/$gBISDir; make -j8 buildworld | tee /home/$gGitUser/$build_world_log'"
   gRemoteExe $vmIP $gRootUser "cd /home/$gGitUser/$gBISDir; make -j8 buildworld | tee /home/$gGitUser/$build_world_log"
   gLogMsg "gRemoteCopy $vmIP $gGitUser '/home/$gGitUser/$build_world_log' $gLogDir/"
   gRemoteCopy $vmIP $gGitUser "/home/$gGitUser/$build_world_log" $gLogDir/
   ## check whether build world is successful
   $world_build_mark = select-string -pattern ">>> World build" -path $gLogDir/$build_world_log | measure-object|select-object -expand count
   if ($world_build_mark -ne 2) {
      gLogMsg "World build failed! See the details in $gLogDir/$build_world_log"
      return $False
   }
   return $True
}

function build_kernel([String] $vmIP)
{
   $build_log       = "build_kernel.log"
   $install_log     = "install.log"
   $timestamp       = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $kernel_file     = "kernel_" + ${timestamp} + ".tgz"

   gLogMsg "gRemoteExe $vmIP $gRootUser 'cd /home/$gGitUser/$gBISDir; make -j8 buildkernel | tee /home/$gGitUser/$build_log'"
   gRemoteExe $vmIP $gRootUser "cd /home/$gGitUser/$gBISDir; make -j8 buildkernel | tee /home/$gGitUser/$build_log"
   gLogMsg "gRemoteCopy $vmIP $gGitUser '/home/$gGitUser/$build_log' $gLogDir/"
   gRemoteCopy $vmIP $gGitUser "/home/$gGitUser/$build_log" $gLogDir/

   $kernel_build_mark = select-string -pattern "Kernel build for" -path $gLogDir/$build_log | measure-object|select-object -expand count
   if ($kernel_build_mark -ne 2) {
       gLogMsg "Kernel build failed!"
       return $False
   }
   return $True
}

function install_world_to_image([String] $vmIP, [String] $imgDir)
{
   $install_world_log = "install_world.log"
   gLogMsg "gRemoteExe $vmIP $gRootUser 'cd /home/$gGitUser/$gBISDir; make installworld DESTDIR=$imgDir | tee /home/$gGitUser/$install_world_log'"
   gRemoteExe $vmIP $gRootUser "cd /home/$gGitUser/$gBISDir; make installworld DESTDIR=$imgDir | tee /home/$gGitUser/$install_world_log"
   
   gLogMsg "gRemoteCopy $vmIP $gGitUser '/home/$gGitUser/$install_world_log $gLogDir/"
   gRemoteCopy $vmIP $gGitUser "/home/$gGitUser/$install_world_log" $gLogDir/
   #$install_world_mark = select-string -pattern ">>>" -path $gLogDir/$install_world_log | measure-object|select-object -expand count
   #if ($install_world_mark -ne 2) {
   #    gLogMsg "Install world failed!"
   #    return $False
   #}
   $stop_cnt = select-string -pattern "^Stop" -path $gLogDir/$install_world_log | measure-object|select-object -expand count
   $error_code_cnt = select-string -pattern "^[*]{3,3} Error" -path $gLogDir/$install_world_log | measure-object|select-object -expand count
   if (($stop_cnt -eq 0) -and ($error_code_cnt -eq 0)) {
       gLogMsg "Install world successfully!"
       return $True
   } else {
       gLogMsg "Install world failed!"
       return $False
   }
}

function install_kernel_to_image([String] $vmIP, [String] $imgDir)
{
   $install_kernel_log = "install_kernel.log"
   gLogMsg "gRemoteExe $vmIP $gRootUser 'cd /home/$gGitUser/$gBISDir; make installkernel DESTDIR=$imgDir | tee /home/$gGitUser/$install_kernel_log'"
   gRemoteExe $vmIP $gRootUser "cd /home/$gGitUser/$gBISDir; make installkernel DESTDIR=$imgDir | tee /home/$gGitUser/$install_kernel_log"
   
   gLogMsg "gRemoteCopy $vmIP $gGitUser '/home/$gGitUser/$install_kernel_log $gLogDir/"
   gRemoteCopy $vmIP $gGitUser "/home/$gGitUser/$install_kernel_log" $gLogDir/
   #$install_kernel_mark = select-string -pattern ">>>" -path $gLogDir/$install_kernel_log | measure-object|select-object -expand count
   #if ($install_kernel_mark -ne 1) {
   #    gLogMsg "Install kernel failed!"
   #    return $False
   #}
   $stop_cnt = select-string -pattern "^Stop" -path $gLogDir/$install_kernel_log | measure-object|select-object -expand count
   $error_code_cnt = select-string -pattern "^[*]{3,3} Error" -path $gLogDir/$install_kernel_log | measure-object|select-object -expand count
   if (($stop_cnt -eq 0) -and ($error_code_cnt -eq 0)) {
       gLogMsg "Install world successfully!"
       return $True
   } else {
       gLogMsg "Install world failed!"
       return $False
   }
   return $True
}

function push_ci_branch_to_remote([String] $vmIP)
{
   $push_log = "brh_push.log"
   $state_file = "state.txt"
   gLogMsg "gRemoteExe $vmIP $gGitUser 'cd /home/$gGitUser/$gBISDir; sh ../$rocketDir/shell/builderrata/$gScriptCIBrh $gRelease | tee /home/$gGitUser/$push_log; echo $? > /home/$gGitUser/$state_file'"
   gRemoteExe $vmIP $gGitUser "cd /home/$gGitUser/$gBISDir; sh ../$rocketDir/shell/builderrata/$gScriptCIBrh $gRelease | tee /home/$gGitUser/$push_log; echo $? > /home/$gGitUser/$state_file"
   gLogMsg "gRemoteCopy $vmIP $gGitUser '/home/$gGitUser/$push_log' $gLogDir/"
   gRemoteCopy $vmIP $gGitUser "/home/$gGitUser/$push_log" $gLogDir/
   gLogMsg "gRemoteCopy $vmIP $gGitUser '/home/$gGitUser/$state_file' $gLogDir/"
   gRemoteCopy $vmIP $gGitUser "/home/$gGitUser/$state_file" $gLogDir/
   $state_content = Get-Content $gLogDir/$state_file
   if (-not $state_content) {
      gLogMsg "Fail to get state file"
      return $False
   }
   foreach ($line in $state_content) {
      if ($line -match "0") {           
          return $True
      }             
   }
   return $False
}

function test_install_world_kernel([String] $vmIP, [String] $imgDir)
{
    $sts = install_world_to_image $vmIP $gMntDir
    if (-not $sts[-1]) {
        $sts = install_kernel_to_image $vmIP $gMntDir
        if (-not $sts[-1]) {
            gLogMsg "Successfully install world and kernel"
        }
    } else {
        gLogMsg "Fail to install world!"
    }

    return $sts
}

function create_raw_vhd([String] $targetVHDName)
{
  $src_vhd_path = "\\" + $gRemoteServer + "\d`$" + $gRelativePath + "\" + $gSrcVHDName
  $dst_vhd_path = "\\" + $gRemoteServer + "\d`$" + $gRelativePath + "\" + $targetVHDName
  gLogMsg "copy-item $src_vhd_path $dst_vhd_path"
  $sts = copy-item $src_vhd_path $dst_vhd_path
  if ($sts) {
      gLogMsg "Fail to copy vhd"
      return $False
  } else {
      gLogMsg "Successfully copy vhd"
      return $True
  }
}

function prepare_vhd([String] $targetVHDName)
{
    $ret = gStartVM $gVmName $gRemoteServer
    if (-not $ret[-1]) {
       return $ret
    }
    
    $vmIP = GetIPv4ViaHyperV $gVmName $gRemoteServer
    if ($vmIP -eq $null) {
       gLogMsg "Cannot get the VM 'gVmName' IP"
       return $False
    }

    if ($gBuildWorld) {
       $prepare_sts = prepare_build $vmIP
       if (-not $prepare_sts[-1]) {
           gLogMsg "Fail to rebase the code"
           return $False
       }
       if ($gMlx4Config) {
           # build mlx4 module
           $mlx4 = prepare_mlx4_before_build $vmIP
           if ($mlx4) {
              gLogMsg "Successful configure mlx4 module in GENERIC"
           } else {
              gLogMsg "Fail to configure mlx4 module in GENERIC"
              return $False
           }
       }
       gLogMsg "Start to build world"
       $world_build_sts = build_world $vmIP
       if ($world_build_sts) {
           $kernel_build_sts = build_kernel $vmIP
           if (-not $kernel_build_sts[-1]) {
               gLogMsg "Fail to build kernel"
               return $False
           }
       } else {
           gLogMsg "Fail to build world"
           return $False
       }
    }

    $ret = create_raw_vhd $targetVHDName
    if (-not $ret[-1]) {
       gLogMsg "Fail to generate VHD: '$targetVHDName'"
       return $ret
    }
    
    $diskHasAttached = attach_vhd $vmIP
    if (-not $diskHasAttached[-1]) {
       gLogMsg "Fail to attach disk"
       return $False
    }
    
    $imageHasMounted = mount_image_if_not_mounted $vmIP
    if (-not $imageHasMounted[-1]) {
       gLogMsg "Fail to mount image"
       return $False
    }

    if ($gBuildWorld) {
        $ret = install_world_to_image $vmIP $gMntDir
        if (-not $ret[-1]) {
            gLogMsg "Fail to install world!"
            umount_image $vmIP
            detach_vhd_if_attached $vmIP
            return $False
        }
        gLogMsg "Successfully install world to '$gMntDir'"
        $ret = install_kernel_to_image $vmIP $gMntDir
        if (-not $ret[-1]) {
            gLogMsg "Fail to install kernel!"
            umount_image $vmIP
            detach_vhd_if_attached $vmIP
            return $False
        }
        gLogMsg "Successfully install kernel to '$gMntDir'"
        if ($gPushCI) {
            $sts = push_ci_branch_to_remote $vmIP
            if (-not $sts[-1]) {
               gLogMsg "Successfully push ci branch to remote"
            } else {
               gLogMsg "Fail to push ci branch to remote"
               umount_image $vmIP
               detach_vhd_if_attached $vmIP
               return $False
            }
        }
    }
    $imageHasUmounted = umount_image $vmIP
    if (-not $imageHasUmounted[-1]) {
       return $False
    }
    
    $diskHasDetached = detach_vhd_if_attached $vmIP
    if (-not $diskHasDetached[-1]) {
       return $False
    }
    
    return $True
}
