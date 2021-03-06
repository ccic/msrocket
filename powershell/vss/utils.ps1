$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$gPPK          = join-path $currentWorkingDir -childPath \..\keys\myPrivate.ppk
$gPlink        = join-path $currentWorkingDir -childPath \..\bin\plink.exe
$gPscp         = join-path $currentWorkingDir -childPath \..\bin\pscp.exe
$gLogDir       = "log"
$gLogFile      = join-path $currentWorkingDir -childPath \$gLogDir\log.txt

function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   echo $OutputMsg >> $gLogFile
}

function gRemoteExe([String] $vmIP,
                    [String] $user,
                    [String] $exeCmd) {
    $cmdExpr = "$gPlink -i $gPPK $user@$vmIP `"$exeCmd`""
    gLogMsg "$cmdExpr"
    $ret = Invoke-Expression $cmdExpr
    return "$ret"
}

function gCopyFromRemote([String] $vmIP,
                     [String] $user,
                     [String] $srcFilePath,
                     [String] $dstFilePath) {
    $cmdExpr = "$gPscp -i $gPPK ${user}@${vmIP}:$srcFilePath $dstFilePath"
    gLogMsg "$cmdExpr"
    $ret = Invoke-Expression $cmdExpr
    return "$ret"
}

function gCopyToRemote([String] $vmIP,
                     [String] $user,
                     [String] $srcFilePath,
                     [String] $dstFilePath) {
    $cmdExpr = "$gPscp -i $gPPK $srcFilePath ${user}@${vmIP}:$dstFilePath"
    gLogMsg "$cmdExpr"
    $ret = Invoke-Expression $cmdExpr
    return "$ret"
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

function WaitForVMToStartKVP([String] $vmName, [String] $server, [int] $timeout)
{
    <#
    .Synopsis
        Wait for the Linux VM to start the KVP daemon.
    .Description
        Wait for a Linux VM with the LIS components installed
        to start the KVP daemon.
    .Parameter vmName
        Name of the VM to test.
    .Parameter server
        Server hosting the VM.
    .Parameter timeout
        Timeout in seconds to wait.
    .Example
        WaitForVMToStartKVP "testVM" "localhost"  300
    #>

    $ipv4 = $null
    $retVal = $False

    $waitTimeOut = $timeout
    while ($waitTimeOut -gt 0)
    {
        $ipv4 = GetIPv4ViaHyperV $vmName $server
        if ($ipv4)
        {
            return $True
        }

        $waitTimeOut -= 10
        Start-Sleep -s 10
    }

    Write-Error -Message "WaitForVMToStartKVP: VM ${vmName} did not start KVP within timeout period ($timeout)" -Category OperationTimeout -ErrorAction SilentlyContinue
    return $retVal
}

function  WaitForVMToStop ([string] $vmName ,[string]  $hvServer, [int] $timeout)
{
    <#
    .Synopsis
        Wait for a VM to enter the Hyper-V Off state.
    .Description
        Wait for a VM to enter the Hyper-V Off state
    .Parameter vmName
        Name of the VM that is stopping.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Parameter timeout
        Timeout in seconds to wait.
    .Example
        WaitForVMToStop "testVM" "localhost" 300
    a#>

    $tmo = $timeout
    while ($tmo -gt 0)
    {
        Start-Sleep -s 1
        $tmo -= 5

        $vm = Get-VM -Name $vmName -ComputerName $hvServer
        if (-not $vm)
        {
            return $False
        }

        if ($vm.State -eq [Microsoft.HyperV.PowerShell.VMState]::off)
        {
            return $True
        }
    }

    Write-Error -Message "StopVM: VM did not stop within timeout period" -Category OperationTimeout -ErrorAction SilentlyContinue
    return $False
}

#######################################################################
#Checks if the VSS Backup daemon is running on the Linux guest  
#######################################################################
function CheckVSSDaemon([string] $ipv4)
{
    $retValue = $False
    
	gRemoteExe ${ipv4} "root" "ps ax | grep '[h]v_vss_daemon' > /root/vss"
    
    if (-not $?)
    {
        Write-Error -Message  "ERROR: Unable to run ps -ef | grep hv_vs_daemon" -ErrorAction SilentlyContinue
        Write-Output "ERROR: Unable to run ps -ef | grep hv_vs_daemon"
        return $False
    }

	gCopyFromRemote ${ipv4} "root" "/root/vss" "."
    if (-not $?)
    {
       
       Write-Error -Message "ERROR: Unable to copy vss from the VM" -ErrorAction SilentlyContinue
       Write-Output "ERROR: Unable to copy vss from the VM"
       return $False
    }

    $filename = ".\vss"
  
    # This is assumption that when you grep vss backup process in file, it will return 1 lines in case of success. 
    if ((Get-Content $filename  | Measure-Object -Line).Lines -eq  "1" )
    {
        Write-Output "VSS Daemon is running"  
        $retValue =  $True
    }    
    del $filename   
    return  $retValue 
}

#######################################################################
# Check boot.msg in Linux VM for Recovering journal. 
#######################################################################
function CheckRecoveringJ([string] $ipv4)
{
    $retValue = $False
    gCopyFromRemote ${ipv4} "root" "/var/log/messages" ./boot.msg

    if (-not $?)
    {
      Write-Output "ERROR: Unable to copy boot.msg from the VM"
       return $False
    }

    $filename = ".\boot.msg"
    $text = "recovering journal"
    
    $file = Get-Content $filename
    if (-not $file)
    {
        Write-Error -Message "Unable to read file" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }

    foreach ($line in $file)
    {
        if ($line -match $text)
        {           
            $retValue = $True 
            Write-Output "$line"          
        }             
    }

    del $filename
    return $retValue    
}