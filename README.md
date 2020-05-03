Sysrcd-Gentoo-Wireless
======================

In order to complete my journey porting the B43 wireless drivers to iPXE,
I formed a version of SystemRescueCD that can PXE boot wirelessly.

The normal SystemRescueCD pxe boot process relies on an ethernet connection to
download sysrcd.dat. When the kernel command line is booted with "wifi"
(no quotes), this pxe boot process becomes supported by the wifi. 

Wireless connection can be automated or performed manually at boot-time.

Pre-Populated wpa_supplicant.conf
=================================

A pre-populated wpa_supplicant.conf may be embedded into the initramfs,
to automate wireless connection. Simply extend the already present
overlay-initramfs-wireless/etc/wpa_supplicant.conf, which is automatically
built into the initramfs.

CAVEAT: Due to the new build system's attempt
to gel well the old system, the wpa_supplicant.conf file is copied to
/worksrc/sysresccd-bin/overlay-initramfs/etc/wpa_supplicant.conf. If you
have already started the build, you may need to modify *this* file
instead.

Manual Boot-time Wifi Connection
================================

If no wpa_supplicant configuration is pre-built into the initramfs,
or if those networks cannot be connected, a command-line menu will spawn
with options to facilitate enabling your wireless connection.

These options include editing wpa_supplicant.conf, using `wpa_cli`
directly, or spawning a shell to perform any other required actions (ie
diagnosis, loading a kernel module, etc.)

Etc Etc
=======

Consider this a cutting edge prototype. I give no guarantee that it will
work for you.

This is a fork of brulzki's fork of System Rescue CD 5.3.2 (the last
gentoo-based version of System Rescue CD). Surprisingly, the original fork
did not have complete build scripts, and even the true System Rescue CD source code
itself seems it was left behind incomplete; there were definitely other
external scripts used to build the original. So I put most of the puzzle back together.

Additionally, I paved my way to get wireless driver support at boot time,
with a specific focus on Broadcom's wl driver. I have successfully been
able to boot wirelessly from ipxe using my port of the b43 drivers,
into this modified System Rescue CD that can download the sysrcd.dat
wirelessly.

Since my interest in this package does not come from actual CD usage, the
iso is untested.


Dependencies
------------

The following packages must be install in the build environment.

- dev-util/catalyst
- sys-kernel/genkernel -- Actually, I believe this package is not needed
	on the *host*, as it is installed and invoked separately in the Catalyst chroot environment.
- sys-boot/grub
- app-arch/cpio
- app-arch/pixz
- dev-libs/libisoburn

Building
--------

> `sudo ./build.sh`

This script prepares the necessary build area in `/worksrc`, which is used during the building process. Then the catalyst stages are invoked, the kernels are built and finally the iso image is generated.
