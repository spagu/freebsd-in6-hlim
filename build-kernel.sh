#!/bin/sh
#
# build-kernel.sh - rebuild the GENERIC kernel on starlink with local fixes.
#
# Applies in6-selecthlim-detach.patch (FreeBSD PR 279653: page fault in
# in6_selecthlim() when a TCP timer fires while iwlwifi(4) is detaching),
# drops the experimental atkbdc(4) resume hook from 2026-09-14, then builds
# and installs the kernel plus all modules from /usr/src.  The modules pick up
# the other in-tree fixes already present there: linux_event.c (PR 298878) and
# ichiic (PR 298558).
#
# Run as root; reboot afterwards.  freebsd-update overwrites the kernel, so run
# this again after every base update.  The previous kernel stays bootable as
# /boot/kernel.old and the whole system in boot environment pre-kernel-<date>.
#
set -eu
SRC=/usr/src
DIR=$(cd "$(dirname "$0")" && pwd)
PATCH="$DIR/in6-selecthlim-detach.patch"
ATKBDC="$SRC/sys/dev/atkbdc/atkbdc_isa.c"
STAMP=$(date +%Y-%m-%d)

if grep -q in6_ifhlim "$SRC/sys/netinet6/in6_src.c"; then
	echo ">> in6_selecthlim patch already present"
else
	echo ">> applying $PATCH"
	patch -s -p1 -d "$SRC" < "$PATCH"
fi

if [ -e "$ATKBDC.orig" ] && grep -q atkbdc_isa_resume "$ATKBDC"; then
	echo ">> restoring stock atkbdc_isa.c (instrumented copy kept as .resume-hook)"
	cp -p "$ATKBDC" "$ATKBDC.resume-hook"
	cp -p "$ATKBDC.orig" "$ATKBDC"
fi

bectl create "pre-kernel-$STAMP" 2>/dev/null || echo ">> BE pre-kernel-$STAMP already exists"

echo ">> buildkernel (log: /var/log/build-kernel-$STAMP.log)"
make -C "$SRC" -j"$(sysctl -n hw.ncpu)" buildkernel KERNCONF=GENERIC \
    > "/var/log/build-kernel-$STAMP.log" 2>&1
make -C "$SRC" installkernel KERNCONF=GENERIC >> "/var/log/build-kernel-$STAMP.log" 2>&1
echo ">> installed; reboot to use it. Check: ls -l /boot/kernel/linux64.ko /boot/kernel/ig4.ko"
