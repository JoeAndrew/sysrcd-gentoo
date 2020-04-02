subarch: amd64
version_stamp: krnl
target: livecd-stage2
rel_type: default
profile: default/linux/amd64/17.0
snapshot: 20181110
source_subpath: default/livecd-stage1-amd64-mini
portage_confdir: /worksrc/sysresccd-src/portage-etc-x86
portage_overlay: /worksrc/sysresccd-src/portage-overlay

# fstype "none" is not a valid type, it will cause catalyst to fail at
# this point but that is the desired behavior and OKAY.
livecd/fstype: none
livecd/cdtar: /usr/share/catalyst/livecd/cdtar/isolinux-3.72-cdtar.tar.bz2
livecd/iso: /worksrc/isofiles/systemrescuecd-amd64-current.iso
livecd/splash_type: 
livecd/splash_theme: 
livecd/bootargs: dokeymap
livecd/gk_mainargs: --makeopts="-j5" --integrated-initramfs
livecd/type: generic-livecd
livecd/readme:
livecd/motd: 
livecd/modblacklist:
livecd/overlay: /worksrc/sysresccd-src/overlay-iso-x86
livecd/users:

boot/kernel: rescue64

boot/kernel/rescue64/sources: sys-kernel/std-sources
boot/kernel/rescue64/config: /worksrc/sysresccd-src/kernelcfg/config-std-x86_64.cfg
boot/kernel/rescue64/use: pcmcia usb -X png truetype 
boot/kernel/rescue64/extraversion: amd64
boot/kernel/rescue64/packages:
	app-emulation/open-vm-tools
# at this point, open-iscsi failed with undefined reference to "best_match_bufcmp"
# but, it compiled in stage2 32-bit and so it *should* work, but I haven't
# tested it since I don't use this at all.
#	sys-block/open-iscsi
