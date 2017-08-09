$Nightly_Task_Name = "BIS_Nightly_Shutdown_VMs"

disable-scheduledtask -TaskName $Nightly_Task_Name
get-scheduledtask -TaskName $Nightly_Task_Name
