#!/bin/sh
. perf_env.sh

send_mail()
{
   local html_summary_path=$1
   local subject=${subject_prefix}${result_dir}
   local server_ip=`ifconfig hn0 | grep "inet "|awk '{print $2}'`
   local href=""
   local tmp=""
   local len=`echo ""|awk -v a=$html_summary_path '{printf("%d\n", length(a))}'`
   local slash=`echo $html_summary_path|cut -c $len`
   if [ $slash == "/" ]
   then
      let len=$len-1
      html_summary_path=`echo $html_summary_path|cut -c -$len`
   fi
   local curr_dir=${html_summary_path##*/}
   html_href="${web_protocol}://$server_ip/$curr_dir/$summary_html_file"
   cat << EOF > /tmp/send_mail.txt
subject:<BIS>$subject</BIS>
from:$from
Performance result: $html_href
EOF
   cat << EOF >> /tmp/send_mail.txt

Auto generated mail. Never reply it.
EOF
   sendmail $receivers_list < /tmp/send_mail.txt
}
if [ $# -ne 1 ]
then
   echo "Specify folder"
   exit 1
fi
send_mail $*
