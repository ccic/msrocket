$Nightly_Task_Name = "BIS_Nightly_Shutdown_VMs"

enable-scheduledtask -TaskName $Nightly_Task_Name
get-scheduledtask -TaskName $Nightly_Task_Name
