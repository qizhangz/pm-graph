#!/bin/sh

#export https_proxy="http://proxy-dmz.intel.com:912/"
#export http_proxy="http://proxy-dmz.intel.com:911/"
#export no_proxy="intel.com,.intel.com,localhost,127.0.0.1"
#export socks_proxy="socks://proxy-dmz.intel.com:1080/"
#export ftp_proxy="ftp://proxy-dmz.intel.com:911/"

STCFG="/home/tebrandt/workspace/pm-graph/config/stresstest-intel-local.cfg"
STCMD="/home/tebrandt/workspace/pm-graph/stresstest.py -config $STCFG"
STDIR="/home/tebrandt/workspace/stressconfig"
STMAC="$STDIR/machine.txt"
STOUT="/home/tebrandt/pm-graph-test"
STPKG="/home/tebrandt/workspace/packages"

printUsage() {
	echo "USAGE: stresstest.sh command <args>"
	echo "COMMANDS:"
	echo "   info - show the current kernel version and package files"
	echo "   reset - remove the current log and update the machines file"
	echo "   online <restart> - check which machines are online"
	echo "       restart: attempt a restart of offline machines"
	echo "   install - install the kernel and tools on online machines"
	echo "   ready - verify installs worked and machines are ready for test"
	echo "   run - start stress testing on all ready machines"
	echo "   runmulti - start stress testing using sleepgraph -multi"
	echo "   getmulti - scp stress test output from runmulti run"
	echo "   status - show the test logs for each machine"
	echo "   report - process the data from a completed run and publish it"
	exit 0
}

getKernel() {
	KFILE="/home/tebrandt/workspace/stressconfig/kernel.txt"
	if [ ! -e $KFILE ]; then
		echo "ERROR: missing the kernel version in kernel.txt"
		echo "- $KFILE"
		exit 1
	fi
	KERNEL=`cat $KFILE`
	if [ -z "$KERNEL" ]; then
		echo "ERROR: kernel is blank in kernel.txt"
		echo "- $KFILE"
		exit 1
	fi
	IMAGE=`find $STPKG -name linux-image-*$KERNEL*.deb`
	HEADERS=`find $STPKG -name linux-headers-*$KERNEL*.deb`
	if [ -z "$IMAGE" -o -z "$HEADERS" ]; then
		echo "ERROR: $KERNEL kernel packages are missing"
		echo "- $STPKG"
		exit 1
	fi
}

if [ $# -gt 2 -o $# -lt 1 ]; then printUsage; fi

OUTDIR="/media/zeus/pm-graph-test"
getKernel
if [ $1 = "help" ]; then
	printUsage
elif [ $1 = "info" ]; then
	echo "The current linux kernel is $KERNEL"
	echo "These are the package files:"
	cd $STPKG
	ls -l *$KERNEL*.deb | cut -c 36-
	echo "These are the machines currently defined:"
	cat $STMAC
elif [ $1 = "reset" ]; then
	rm -f /home/tebrandt/.ssh/known_hosts
	cp -f $STMAC $STDIR/machine-$KERNEL.txt
#	labmachine qlist > $STMAC
	cat $STMAC
elif [ $1 = "online" ]; then
	if [ $# -eq 1 ]; then
		$STCMD -kernel $KERNEL -userinput online
	elif [ $# -eq 2 -a "$2" = "restart" ]; then
		$STCMD -kernel $KERNEL online
	else
		echo "ERROR: invalid argument for online - $2"
		printUsage
	fi
elif [ $1 = "turbostat" ]; then
	$STCMD turbostat
elif [ $1 = "init" ]; then
	$STCMD -kernel $KERNEL init
elif [ $1 = "reboot" ]; then
	$STCMD -kernel $KERNEL reboot
elif [ $1 = "tools" ]; then
	$STCMD -kernel $KERNEL tools
elif [ $1 = "install" ]; then
	$STCMD -kernel $KERNEL install
elif [ $1 = "uninstall" ]; then
	$STCMD -kernel $KERNEL uninstall
elif [ $1 = "ready" ]; then
	$STCMD -kernel $KERNEL ready
elif [ $1 = "run" ]; then
	$STCMD -kernel $KERNEL -testout $OUTDIR -mode freeze -duration 1440 run
elif [ $1 = "runquick" ]; then
	$STCMD -kernel $KERNEL -testout $OUTDIR -mode freeze -duration 60 runmulti
elif [ $1 = "runmulti" ]; then
	$STCMD -kernel $KERNEL -mode freeze -duration 1440 runmulti
elif [ $1 = "runmultimem" ]; then
	$STCMD -kernel $KERNEL -mode mem -duration 1440 runmulti
elif [ $1 = "getmulti" ]; then
	$STCMD -kernel $KERNEL getmulti
elif [ $1 = "status" ]; then
	$STCMD -kernel $KERNEL -testout $OUTDIR status
elif [ $1 = "report" ]; then
	URL="http://otcpl-stress.ostc.intel.com/pm-graph-test"
	WEBDIR="/home/tebrandt/pm-graph-test"
	SORTDIR="/home/tebrandt/pm-graph-sort"
	MS="/home/tebrandt/.machswap"
	GS="python3 /home/tebrandt/workspace/pm-graph/stressreport.py"
	ARGS="-bugzilla -webdir $WEBDIR -sortdir $SORTDIR -machswap $MS -parallel 8"
	cd $WEBDIR
	$GS $ARGS -urlprefix $URL/$KERNEL -stype sheet -genhtml -create both $KERNEL
else
	echo "\nUNKNOWN COMMAND: $1\n"
	printUsage
fi
