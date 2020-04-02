#!/bin/busybox ash
if [ -f "/showmodprobe" ]
then
	modpath="/lib/modules/$(uname -r)/"
	modinmem="$(cat /proc/modules | awk '{print $1}' | xargs | sed -e 's! !|!g')"
	/sbin/modprobe --show-depends $@ | grep ^insmod | grep -vE "${modinmem}" | sed -e "s!${modpath}!!" > /dev/console
fi
/sbin/modprobe $@
exit $?

