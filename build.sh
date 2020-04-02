#!/bin/bash
# catalyst 4.0.9 exits with a zero-status even on error, so this setting
# doesn't do much good.
set -e
# echo all commands being executed
set -x

# check for missing packages
if [[ ! -f /usr/bin/catalyst || ! -f /usr/bin/genkernel ||
      ! -d /usr/lib/grub/x86_64-efi || ! -f /bin/cpio ||
      ! -f /usr/bin/pixz || ! -f /usr/bin/xorriso ]]; then
    cat <<-EOF
	ERROR: Missing required packages to build sysrescd iso
	# emerge catalyst genkernel grub cpio pixz libisoburn
	EOF
    exit 1
fi

# /worksrc is the sysrcd build area
if [[ ! -d /worksrc/sysresccd-src ]]; then
    mkdir -p /worksrc
# Don't use git clone because it does not allow me to test uncommitted
# changes
    cp -a . /worksrc/sysresccd-src
# TODO: When we are rest assured that /worksrc/sysresccd-src does not
# undergo modifications during build, let's just symlink it to our project
# directory
fi

if [[ ! -e /worksrc/catalyst ]]; then
    ln -s /var/tmp/catalyst /worksrc/catalyst
fi

mkdir -p /worksrc/isofiles
mkdir -p /worksrc/sysresccd-bin/kernels-x86

mkdir -p /worksrc/sysresccd-bin/overlay-initramfs
# note by bazz: instead of populating the initramfs, since I don't know
# HOW it gets populated, I am just using the initramfs.igz from the actual
# CD 5.3.2. IT's working well
cp -a ./overlay-initramfs/* /worksrc/sysresccd-bin/overlay-initramfs
cp -a ./overlay-initramfs-wireless/* /worksrc/sysresccd-bin/overlay-initramfs

mkdir -p /worksrc/sysresccd-bin/overlay-iso-x86

if [[ ! -d /worksrc/sysresccd-bin/overlay-iso-x86/isolinux ]]; then
    mkdir -p /worksrc/sysresccd-bin/overlay-iso-x86/isolinux
    cp -p /usr/share/syslinux/isolinux.bin \
       /worksrc/sysresccd-bin/overlay-iso-x86/isolinux
    cp -p /usr/share/syslinux/{ifcpu64,kbdmap,menu,reboot,vesamenu}.c32 \
       /worksrc/sysresccd-bin/overlay-iso-x86/isolinux
    cp -p /usr/share/syslinux/{ldlinux,libcom32,libutil}.c32 \
       /worksrc/sysresccd-bin/overlay-iso-x86/isolinux
fi

# SquashFS overlay
if [[ ! -d /worksrc/sysresccd-bin/overlay-squashfs-x86 ]]; then
  mkdir -p /worksrc/sysresccd-bin/overlay-squashfs-x86
  cp -a overlay-squashfs-x86 /worksrc/sysresccd-bin
# Add wireless settings files
  cp -a overlay-squashfs-wireless /worksrc/sysresccd-bin/overlay-squashfs-x86
fi

# Catalyst conf file. By specifying this file to catalyst calls, we forego
# the need to overwrite /etc/catalyst/catalyst.conf. WARNING: The
# 'default' "class" is still used, so if you have a catalyst setup for
# something else in default, and don't want to mix it, you need to look
# into what needs to be done in the call to catalyst or the spec files to
# use a different "class". (i cant recall the actual title, so I'm saying
# "class")
cconf='mainfiles/catalyst.conf-x86'

. ${cconf}
# populate the catalyst portdir (/var/db/repos/srcd)
if [[ ! -d ${portdir} ]]; then
  mkdir -p ${portdir}
# extract the snapshot (we'll include it in the project)
  tar Jxvf portage-20181022.tar.xz -C ${portdir} --strip 1
fi
# populate the catalyst distdir 
# since the snapshot I used is from 2018, some of the
# distfiles might not be located during download. In my experience, this
# was also due to catalyst's chroot wget not having SSL capability.
#I added the ssl USE flag to wget, but I'm convinced more packages will
# not fetch. For this reason, I will host distfiles. Until we possibly get
# this compiling from a current snapshot
if [[ ! -d ${distdir} ]]; then
  mkdir -p ${distdir}
# Download and extract the distdir
  wget https://bazz1.com/bazz/srcd/distfiles-srcd.tar.gz
  tar zxvf distfiles-srcd.tar.gz -C ${distdir} --strip 1

# INCASE you are wondering why .gz; here is a comparison, stemming from
# the fact that practically all distfiles are pre-compressed.
## ls -l distfiles-srcd.tar* (compression speed)
# 1781524480  distfiles-srcd.tar (fast)
# 1761904724  distfiles-srcd.tar.bz2 (slow)
# 1768549747  distfiles-srcd.tar.gz (fast)
# 1761904724  distfiles-srcd.tar.xz (very slow)
fi

# Actually, the snapshot I am using is from 2018-10-22; it was the closest
# date I could find online to the data originally shown here: 2018-11-10.
# For now, I have renamed my snapshot to fit these names, but later I plan
# on updating (down dating? x) all files to use the true date.
# snapshot the portage tree
if [[ ! -f /var/tmp/catalyst/snapshots/gentoo-20181110.tar.bz2 ]]; then
    catalyst -c ${cconf} -s 20181110
fi

# TODO compress these seed stages and store locally, because we don't know
# how long they will be available online

# fetch a 32bit seed stage
if [[ ! -f /var/tmp/catalyst/builds/default/stage1-i686-baseos.tar.bz2 ]]; then
    mkdir -p /var/tmp/catalyst/builds/default/
    wget -O /var/tmp/catalyst/builds/default/stage1-i686-baseos.tar.bz2 \
         https://downloads.sourceforge.net/project/systemrescuecd/sysresccd-sdk/stage1-i686-baseos-5.3.1.tar.bz2
fi

# fetch a 64 bit seed stage
if [[ ! -f /var/tmp/catalyst/builds/default/stage1-amd64-baseos.tar.bz2 ]]; then
  mkdir -p /var/tmp/catalyst/builds/default/
  wget -O /var/tmp/catalyst/builds/default/stage1-amd64-baseos.tar.bz2 \
    https://downloads.sourceforge.net/project/systemrescuecd/sysresccd-sdk/stage1-amd64-baseos-5.3.1.tar.bz2
fi

# We have a seed already
#catalyst -f mainfiles/sysresccd-base-stage1-i686.spec

# SRCD uses a 32-bit environment so that both 32-bit and 64-bit kernels
# can run the same binaries. This means that we must build both 32-bit and
# 64-bit specs to run on 64-bit system.
catalyst -c ${cconf} -f mainfiles/sysresccd-base-stage2-i686.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-base-stage3-i686.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-base-stage4-i686.spec

# Build the full ISO. There is currently no way to specify the mini one.
# Note that this is also currently hardcoded at buildscripts/recreate-iso.sh:55
# where CDTYPE is declared
catalyst -c ${cconf} -f mainfiles/sysresccd-live-stage1-full-i686.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-live-stage2-full.spec

# bazz additions; even when building a 'full' image, the mini ones are
# still used to generate the kernels, so we need to build them too.
catalyst -c ${cconf} -f mainfiles/sysresccd-live-stage1-mini-i686.spec
# catalyst intentionally fails at the filesystem stage vvvv ( we didn't
# want to build a fs this time)
buildscripts/rebuild-kernel.sh rescue32

# 64 bit
# We have a seed already
#catalyst -f mainfiles/sysresccd-base-stage1-amd64.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-base-stage2-amd64.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-base-stage3-amd64.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-base-stage4-amd64.spec
catalyst -c ${cconf} -f mainfiles/sysresccd-live-stage1-amd64.spec #mini
# catalyst intentionally fails at the filesystem stage vvvv
buildscripts/rebuild-kernel.sh rescue64

buildscripts/recreate-iso.sh x86
