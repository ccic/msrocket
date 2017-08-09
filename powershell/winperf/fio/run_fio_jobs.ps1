$currentWorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

. $currentWorkingDir\fio_env.ps1

function run_fio([String] $odir)
{
   
   $outdir = join-path $currentWorkingDir $odir
   $fio_log_path = join-path $outdir $fio_log_file
   wget -TimeoutSec 50 -Uri checkip.dyndns.org -OutFile $fio_log_path
   $iter=1
   $bslist = $fio_block_size_list.split(" ")
   foreach($bs in $bslist)
   {
      $modes = $fio_modes.split(" ")
      foreach($md in $modes)
      {
         $numjobs = $fio_numjobs_list.split(" ")
         foreach($th in $numjobs)
         {
            $iodepths = $fio_iodepth_list.split(" ")
            foreach($io in $iodepths)
            {
               $iterjob="job" + ${iter}
               $jobname="fio-job" + ${iter} + "-" + $md + "-" + $bs + "k-" + $io + "-" + $th
               echo "$jobname"
               $fio_config = @"
[global]
bs=${bs}k
ioengine=$fio_engine
iodepth=$io
size=$fio_size
direct=1
runtime=$fio_runtime
filename=$fio_filename

[$iterjob]
rw=$md
stonewall
"@
               $fio_config_fname = $jobname + ".config"
               $fio_out_fname = $jobname + ".json"
               $fio_config_path = join-path $outdir $fio_config_fname
               $fio_out_path = join-path $outdir $fio_out_fname
               
               $curtime = Get-Date -format yyyy-M-d-HH-mm-ss
               Out-File -InputObject ($fio_config) -FilePath $fio_config_path -Encoding ascii
               $log_info = "${curtime}: fio --group_reporting --output-format=json --numjobs=$th --output=$fio_out_path $fio_config_path "
               Out-File -InputObject ($log_info) -FilePath $fio_log_path -Encoding ascii -Append
               fio --group_reporting --output-format=json --numjobs=$th --output=$fio_out_path $fio_config_path 
               $iter = $iter + 1
            } 
         }
      }
   }
}

$timeStamp4Deply = Get-Date -format yyyy-M-d-HH-mm-ss
$out_dir = "fio-" + $timeStamp4Deply
md $out_dir
run_fio $out_dir
