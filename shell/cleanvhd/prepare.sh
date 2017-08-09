#!/bin/sh
pkg install -y base64
pkg install -y ca_root_nss
pkg install -y python27
pkg install -y Py27-setuptools27 
ln -s /usr/local/bin/python2.7 /usr/bin/python 
pkg install -y git sudo

git clone https://github.com/Azure/WALinuxAgent.git
cd WALinuxAgent
git checkout 2.1
python setup.py install
ln -sf /usr/local/sbin/waagent /usr/sbin/waagent
ln -sf /usr/local/sbin/waagent2.0 /usr/sbin/waagent2.0
#echo "y" |  /usr/local/sbin/waagent -deprovision
echo  'waagent_enable="YES"' >> /etc/rc.conf 

