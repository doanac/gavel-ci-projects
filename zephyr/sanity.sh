#!/bin/bash -e

status() {
	echo = $*
}

indented() {
	$* 2>&1 | sed 's/^/ | /'
}

if [ -z $SUDO_USER ] ; then
	status "Running script with: sudo $0 $*"
	exec sudo -E $0 $*
fi

if [ -n "$PLATFORM" ] ; then
	if [ "$PLATFORM" = "nrf52_blenano2" ] ; then
		PYOCD_BOARD_NAME="RedBearLab-BLE-Nano2"
	else
		echo "ERROR: Unknown platform name for this script: $PLATFORM"
		exit 1
	fi
else
	echo "ERROR: Missing required environment variable: \$PLATFORM"
	exit 1
fi

status "Installing dependencies"
dtc --version | grep "1.4.7" > /dev/null || (echo " *Installing dtc 1.4.7" && indented wget -O /tmp/dtc.deb http://security.ubuntu.com/ubuntu/pool/main/d/device-tree-compiler/device-tree-compiler_1.4.7-1_amd64.deb && indented dpkg -i /tmp/dtc.deb)
python3 -c "import pyudev; import pyocd" || (echo " *Installing pyudev and pyocd" && indented pip3 install pyudev==0.21.0 git+https://github.com/mbedmicro/pyOCD@60e6bf40b713919d9b49ccf4d2753f269d3e6082)


status "Probing for a board named: $PYOCD_BOARD_NAME"
board=$(sudo $(dirname $(readlink -f $0))/pyocd-probe-for $PYOCD_BOARD_NAME)
board_tty=$(echo $board | cut -d\| -f1)
board_uid=$(echo $board | cut -d\| -f2)

status "Probed board tty($board_tty) id($board_uid)"

for b in ${BROKE_TESTS//\\n/ } ; do
	status "Removing broken test: $b"
	rm -rf $b
done

status "Running sanitycheck"
. zephyr-env.sh
set -x
sanitycheck  \
	--platform $PLATFORM \
	--inline-logs \
	--outdir /tmp/outdir \
	--enable-slow \
	--verbose \
	--ninja \
	--device-testing \
	--device-serial $board_tty \
	-e kernel \
|| true

cp ./scripts/sanity_chk/last_sanity.xml /archive/junit.xml
