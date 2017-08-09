#Requires -RunAsAdministrator
function gLogMsg([String] $msg)
{
   $Timestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
   $OutputMsg = $Timestamp + ":" + $msg
   echo $OutputMsg
}
$NightlyVM = "nightly"
$NightlyDummy = "nightly_dummy"
$HomeDir=join-path $HOME -childPath "Nightly"
cd $HomeDir

$RunningVMs = (Get-VM | Where { $_.State -eq 'Running' }).Name
gLogMsg "All running vms: ==$RunningVMs=="
foreach ($vm in $RunningVMs) {
   gLogMsg "Stop VM '$vm'"
   Stop-VM -Name $vm
}
## The 1st launched VM locates on NUMA1, and 2nd VM 
## locates on NUMA0. Experiments indicate on sh-ostc-perf03,
## VM on NUMA1 shows best network performance.
gLogMsg "Start the nightly VM: '$NightlyDummy'"
Start-VM -Name $NightlyDummy
gLogMsg "Start the nightly VM: '$NightlyVM'"
Start-VM -Name $NightlyVM
get-vmhostnumanodestatus

$RunningVM = (Get-VM | Where { $_.State -eq 'Running' }).Name
if ($RunningVM -eq $NightlyVM) {
   $NumaNodeId = (get-vmhostnumanodestatus|where {$_.VMName -eq "nightly"}).NodeId
   if ($NumaNodeId -eq 0) {
      gLogMsg "Successfully start '$NightlyVM' on expected NUMA node 0"
   } else {
      gLogMsg "'$NightlyVM' is not running on NUMA node 0, performance is bad"
   }
   return $True
} else {
   gLogMsg "Fail to start '$NightlyVM'"
   return $False
}
