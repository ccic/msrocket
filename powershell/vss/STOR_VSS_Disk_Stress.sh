#!/bin/sh

########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"

#######################################################################
# Adds a timestamp to the log file
#######################################################################
LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}
}

#######################################################################
# Updates the summary.log file
#######################################################################
UpdateSummary()
{
    echo $1 >> ~/summary.log
}

#######################################################################
# Keeps track of the state of the test
#######################################################################
UpdateTestState()
{
    echo $1 > ~/state.txt
}

####################################################################### 
# 
# Main script body 
# 
#######################################################################

# Create the state.txt file so ICA knows we are running
UpdateTestState $ICA_TESTRUNNING

# Cleanup any old summary.log files
if [ -e ~/summary.log ]; then
    rm -rf ~/summary.log
fi

pkg info curl
if [ $? -ne 0 ]
then
	pkg install -y curl
fi
#####################
#
# Hardcode the iozone version, it is the latest verion on Sep 23 2016.
# We just want to download stable version here.
#
#####################
iOzoneVers=3_465

curl http://www.iozone.org/src/current/iozone${iOzoneVers}.tar > iozone${iOzoneVers}.tar

# Make sure the iozone exists
IOZONE=iozone$iOzoneVers.tar
if [ ! -e ${IOZONE} ];
then
    LogMsg "Cannot find iozone file."
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi


# Get Root Directory of tarball
ROOTDIR=`tar -tvf ${IOZONE} | head -n 1 | awk -F " " '{print $9}' | awk -F "/" '{print $1}'`

# Now Extract the Tar Ball.
tar -xvf ${IOZONE}
sts=$?
if [ 0 -ne ${sts} ]; then
	LogMsg "Failed to extract Iozone tarball"
	UpdateTestState $ICA_TESTABORTED
    	exit 1
fi

# cd in to directory    
if [ !  ${ROOTDIR} ];
then
    LogMsg "Cannot find ROOTDIR."
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

cd ${ROOTDIR}/src/current

# Compile iOzone
make freebsd64
sts=$?
	if [ 0 -ne ${sts} ]; then
	    LogMsg "Error:  make linux  ${sts}"
	    UpdateTestState "TestAborted"
	    UpdateSummary "make linux : Failed"
	    exit 1
	else
	    LogMsg "make linux : Sucsess"

	fi

# Run Iozone
while [ true ]
do 
  ./iozone -ag 10G
done > /dev/null 2>&1

sts=$?
        if [ 0 -ne ${sts} ]; then
            LogMsg "Error:  running IOzone  Failed ${sts}"
            UpdateTestState "TestAborted"
            UpdateSummary " Running IoZone  : Failed"
            exit 1
        else
            LogMsg "Running IoZone : Sucsess"
            UpdateSummary " Running Iozone : Sucsess"
        fi

UpdateTestState $ICA_TESTCOMPLETED
exit 0