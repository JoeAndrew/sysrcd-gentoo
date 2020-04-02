#!/bin/bash
# Bazz note: I added some Bash stuff for the new initramfs wireless stuff.
# so I edited the shebang accordingly.


VERSION_MAJ=5
VERSION_MIN=3
VERSION_PAT=2

# ==================================================================
# ==================================================================

VERSION="${VERSION_MAJ}.${VERSION_MIN}.${VERSION_PAT}"
VOLNAME="sysrcd-${VERSION_MAJ}.${VERSION_MIN}.${VERSION_PAT}"
GRUBCFG="grub-${VERSION_MAJ}${VERSION_MIN}${VERSION_PAT}.cfg"
ISODIR=/worksrc/isofiles
TEMPDIR=/worksrc/catalyst/isotemp
REPOSRC=/worksrc/sysresccd-src
REPOBIN=/worksrc/sysresccd-bin

# ========= error handling ====================================================
die()
{
	echo "$@" 1>&2
	exit 1
}

# ========= check command line ================================================
usage()
{
	echo "Usage: $0 <arch> <options>"
	echo "  arch = x86 | amd64 | sparc"
}

if [ "$1" = "x86" ] || [ "$1" = "amd64" ] || [ "$1" = "sparc" ]
then
	CURARCH="$1"
else
	usage
	exit 1
fi

# ========= copy files from the temp iso image ================================
CURFILE="${ISODIR}/systemrescuecd-${CURARCH}-current.iso"
MYDATE=$(date +%Y%m%d-%Hh%M)
DESTDIR=/home/sysresccdiso
mkdir -p ${DESTDIR}
test -f "${CURFILE}" || die "Cannot find \"${CURFILE}\". Failed"
mkdir -p /mnt/cdrom
umount /mnt/cdrom 2>/dev/null
mount -o loop,ro ${CURFILE} /mnt/cdrom || die "Cannot mount ${CURFILE}"
test -f /mnt/cdrom/image.squashfs || die "Cannot find a valid file in the ISO"
[ -d ${TEMPDIR} ] && rm -rf ${TEMPDIR} ; mkdir -p ${TEMPDIR}
cp /mnt/cdrom/image.squashfs ${TEMPDIR}/sysrcd.dat
( cd ${TEMPDIR} ; md5sum sysrcd.dat > sysrcd.md5 ; chmod 644 sysrcd.* ) 
# BAZZ NOTE: The image.squashfs.txt was not present in the
# /worksrc/isofiles/....iso file. so i hardcoded to full
CDTYPE=full
#CDTYPE="$(cat /mnt/cdrom/image.squashfs.txt)"
CDVERS="$(cat ${REPOSRC}/overlay-squashfs-x86/root/version)"
# do not unmount yet, because we'll be needing some DLL's for the
# wpa_supplicant that will be going into the shared initramfs for wireless
# support

# ========= update grub modules ================================================
# The modules must match the grub verison which provides /usr/bin/grub-mkimage
# hence they must both come from the OS which runs this script
GRUBDST="${REPOBIN}/overlay-iso-x86/boot/grub/x86_64-efi"
GRUBSRC="/usr/lib64/grub/x86_64-efi"
rm -rf ${GRUBDST}
mkdir -p ${GRUBDST}
rsync -a ${GRUBSRC}/{*.mod,*.lst} "${GRUBDST}/" || die "Failed to rsync grub modules: rsync -a ${GRUBSRC}/{*.mod,*.lst} ${GRUBDST}/"

# ========= copy files from overlays ===========================================
rsync -ax ${REPOBIN}/overlay-iso-x86/ "${TEMPDIR}/"
rsync -ax ${REPOSRC}/overlay-iso-x86/ "${TEMPDIR}/"
cp ${REPOSRC}/overlay-squashfs-x86/root/version "${TEMPDIR}/"

# ========= copy and transform isolinux configuration files=====================
case ${CDTYPE} in
	full)
		filter='<ALL>|<STD>'
		memreq='512 MB'
		;;
	mini)
		filter='<ALL>|<MIN>'
		memreq='256 MB'
		;;
esac

for curfile in ${REPOSRC}/overlay-iso-x86/isolinux/*
do
	if [ -f ${curfile} ]
	then
		filename=$(basename ${curfile})
		isofile1="${REPOSRC}/overlay-iso-x86/isolinux/${filename}"
		isofile2="${TEMPDIR}/isolinux/${filename}"
		grep -E "${filter}" "${isofile1}" >| "${isofile2}"
		sed -i -e 's!<...> !!g' "${isofile2}"
		sed -i -e "s!<MEMREQ>!${memreq}!g" "${isofile2}"
		sed -i -e "s!<SRCDVER>!${CDVERS}!g" "${isofile2}"
	fi
done

# ========= copy kernel images from overlays ===================================
rsync -ax ${REPOBIN}/kernels-x86/{rescue32,rescue64} ${TEMPDIR}/isolinux/ || die "rsync failed to copy std kernels"

# ========= recreate initramfs =================================================
curdir="${TEMPDIR}/isolinux"
newramfs="${curdir}/initram-root"
newinitrfs="${curdir}/initram.igz"

# prepare root of new initramfs
[ -d ${newramfs} ] && rm -rf ${newramfs}
mkdir -p ${newramfs}
cp -a ${REPOBIN}/overlay-initramfs/* ${newramfs}/

# Copy necessary files for wireless, including DLL's from the ISO that
# compiled wpa_supplicant so that it will run from the initramfs
mkdir -p /mnt/squash
mount /mnt/cdrom/image.squashfs /mnt/squash
# The next section analyzes the dependent DLLs needed for wpa supplicant.
# ldd outputs the following format:

# ldd /mnt/squash/usr/sbin/wpa_supplicant
# linux-gate.so.1 (0xf7ef5000)
# librt.so.1 => /lib32/librt.so.1 (0xf7d0a000)
# libnl-3.so.200 => not found
# libnl-genl-3.so.200 => not found
# libssl.so.1.0.0 => not found
# libcrypto.so.1.0.0 => not found
# libdbus-1.so.3 => /usr/lib32/libdbus-1.so.3 (0xf7cb7000)
# libc.so.6 => /lib32/libc.so.6 (0xf7ad0000)
# libpthread.so.0 => /lib32/libpthread.so.0 (0xf7aae000)
# /lib/ld-linux.so.2 (0xf7ef6000)

# I ran ldd from outside the chroot of the sqfs, hence the 'not found'
# messages. We just want the first column, the filenames.

# TODO: use ldd from chroot: chroot /mnt/squash ldd /usr/bin/wpa_cli...
dllfiles1=$(chroot /mnt/squash ldd /usr/sbin/wpa_supplicant | awk '{print $1}')
dllfiles2=$(chroot /mnt/squash ldd /usr/bin/wpa_cli | awk '{print $1}')
dllfiles=$(echo ${dllfiles1} ${dllfiles2} | xargs -n1 | sort -u | \
	grep -v linux-gate | xargs -I{} -n1 find /mnt/squash -name '{}' \
	2>/dev/null)

# awk prints the filename column, we remove the linux-gate since that is
# an internal Linux file, and we search the squash for each dll location,
# which is added to $dllfiles.

wpabins="/usr/sbin/wpa_supplicant /usr/bin/wpa_cli /usr/bin/wpa_passphrase"
wpafiles=$(for bin in $wpabins; do echo /mnt/squash${bin} ; done)

for f in ${wpafiles} ${dllfiles} ; do
  # We are going to make sure the directory component is created in the
  # initramfs, and add those DLL files to the proper locations in the
  # initramfs

  # eg. /mnt/squash/lib/librt.so.1 -> /mnt/squash/lib 
  filename_removed=${f%/*}

  # eg. /mnt/squash/lib -> lib
  prefix_removed=${filename_removed#/mnt/squash/}
	
  mkdir -p ${newramfs}/${prefix_removed}
# Do not copy symlink, but the target file
  cp ${f} ${newramfs}/${prefix_removed}
done
#done with squash
umount /mnt/squash
# we are done with the ISO mount
umount /mnt/cdrom

# setup custom busybox in initramfs
# bazz note: Hard links were not booting correctly. soft works
( cd ${newramfs}/bin/ ; ln -s busybox sh )

# copy the init boot script in the initramfs
cp ${REPOSRC}/mainfiles/init ${newramfs}/init
sed -i -e "s!CDTYPE=''!CDTYPE='${CDTYPE}'!g" ${newramfs}/init

# build new initramfs
echo 'building the new initramfs...'
( cd ${newramfs} && find . | cpio -H newc -o | xz --check=crc32 > ${newinitrfs} )

# remove old igz-images and tmp-dirs
[ -d ${newramfs} ] && rm -rf ${newramfs} 

# ========= copy embedded initramfs to permanent location =====================
# Bazz note: this doesn't work, genkernel seems to no longer store an
# external file of an embedded initramfs. If you must get to these files,
# you can use `binwalk -e [kernel-file]`, then go into the created
# _directory and do another binwalk -e on the hex-named file, and then you
# will see a cpio-archive directory

#mkdir -p /var/tmp/EMBEDDEDINIT
#rsync -ax /worksrc/catalyst/tmp/default/livecd-stage2-*/etc/kernels/initramfs-*.cpio* /var/tmp/EMBEDDEDINIT/

# ========= copy the new files to the pxe environment =========================
if [ -d /tftpboot ]
then
	cp ${TEMPDIR}/sysrcd.dat /tftpboot/
	cp ${TEMPDIR}/sysrcd.md5 /tftpboot/
	cp ${TEMPDIR}/isolinux/* /tftpboot/
fi

# ========= prepare the ISO image =============================================
ISOFILE="${DESTDIR}/systemrescuecd-${CURARCH}-${VERSION}-${CDTYPE}-${MYDATE}.iso"

iso_uuid=$(date -u +%Y-%m-%d-%H-%M-%S-00)
iso_date=$(echo ${iso_uuid} | sed -e s/-//g)

# 1. give "grub.cfg" a sysresccd version specific name
mv "${TEMPDIR}/boot/grub/grub.cfg" "${TEMPDIR}/boot/grub/${GRUBCFG}"
mkdir -p "${TEMPDIR}/efi/boot"

# 2. create memdisk tar image which contains initial embedded grub.cfg
memdisk_dir="/var/tmp/MEMDISKDIR"
memdisk_img="/var/tmp/MEMDISKIMG"
rm -rf ${memdisk_dir} ${memdisk_img}
mkdir -p "${memdisk_dir}/boot/grub"
initialcfg="${memdisk_dir}/boot/grub/grub.cfg"
echo "" >| ${initialcfg}
echo "search --file --no-floppy --set=root /boot/grub/${GRUBCFG}" >> ${initialcfg}
echo "set prefix=/boot/grub" >> ${initialcfg}
echo "source (\${root})/boot/grub/${GRUBCFG} " >> ${initialcfg}
(cd "${memdisk_dir}"; tar -cf - boot) > "${memdisk_img}"

# 3. create bootx64.efi that contains embedded memdisk tar image
/usr/bin/grub-mkimage -m "${memdisk_img}" -o "${TEMPDIR}/efi/boot/bootx64.efi" \
	--prefix='(memdisk)/boot/grub' -d /usr/lib64/grub/x86_64-efi -C xz -O x86_64-efi \
	search iso9660 configfile normal memdisk tar boot linux part_msdos part_gpt \
	part_apple configfile help loadenv ls reboot chain search_fs_uuid multiboot \
	fat iso9660 udf ext2 btrfs ntfs reiserfs xfs lvm ata || die 'grub-mkimage failed'

# 4. create boot/grub/efi.img that contains bootx64.efi
fatdisk_dir="/var/tmp/FATDISKDIR"
fatdisk_img="/var/tmp/FATDISKIMG"
rm -rf ${fatdisk_dir} ${fatdisk_img}
mkdir -p "${fatdisk_dir}/efi/boot"
rsync -a "${TEMPDIR}/efi/boot/bootx64.efi" "${fatdisk_dir}/efi/boot/bootx64.efi" || die "rsync failed to copy bootx64.efi"
mformat -C -f 1440 -L 16 -i "${TEMPDIR}/boot/grub/efi.img" :: || die "mformat failed"
mcopy -s -i "${TEMPDIR}/boot/grub/efi.img" "${fatdisk_dir}/efi" ::/ || die "mcopy failed"

# 5. create iso image
if [ "${CURARCH}" = "x86" ] || [ "${CURARCH}" = "amd64" ]
then
	xorriso -as mkisofs -joliet -rock --modification-date=${iso_date} \
		-omit-version-number -disable-deep-relocation \
		-b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
		-volid ${VOLNAME} -o ${ISOFILE} ${TEMPDIR} || die "xorriso failed"
	#/usr/bin/isohybrid ${ISOFILE}
fi
if [ "${CURARCH}" = "sparc" ]
then
	mkisofs -G /boot/isofs.b -J -V ${VOLNAME} -B ... -r -o ${ISOFILE} ${TEMPDIR} || die "mkisofs failed"
fi

# ========= copy list of packages ===============================================
pkglist_full_std="/var/tmp/catalyst/tmp/default/livecd-stage2-i686-full/root/sysresccd-pkg.txt"
pkglist_full_eix="/var/tmp/catalyst/tmp/default/livecd-stage2-i686-full/root/sysresccd-eix.txt"
pkglist_mini_std="/var/tmp/catalyst/tmp/default/livecd-stage2-i686-mini/root/sysresccd-pkg.txt"
pkglist_mini_eix="/var/tmp/catalyst/tmp/default/livecd-stage2-i686-mini/root/sysresccd-eix.txt"
[ -f "${pkglist_full_std}" ] && cp "${pkglist_full_std}" "${REPOSRC}/pkglist/sysresccd-x86-packages-full-std-${CDVERS}.txt"
[ -f "${pkglist_full_eix}" ] && cp "${pkglist_full_eix}" "${REPOSRC}/pkglist/sysresccd-x86-packages-full-eix-${CDVERS}.txt"
[ -f "${pkglist_mini_std}" ] && cp "${pkglist_mini_std}" "${REPOSRC}/pkglist/sysresccd-x86-packages-mini-std-${CDVERS}.txt"
[ -f "${pkglist_mini_eix}" ] && cp "${pkglist_mini_eix}" "${REPOSRC}/pkglist/sysresccd-x86-packages-mini-eix-${CDVERS}.txt"

# ========= prepare the backup ==================================================
# No idea what this was used for. No such "sysresccd-win*" directory gets
# built from SystemRescueCD source code
#tar -c -z -f "${DESTDIR}/systemrescuecd-${CURARCH}-${VERSION}-${CDTYPE}-${MYDATE}.tar.gz" --exclude='.git' ${REPOSRC} ${REPOBIN} /worksrc/sysresccd-win*

# ========= force recompilation of sys-apps/sysresccd-scripts ===================
rm -f /var/tmp/catalyst/packages/default/livecd-stage2-*/sys-apps/sysresccd-*.tbz2
rm -f /var/tmp/catalyst/packages/default/livecd-stage2-*/sys-kernel/genkernel-*.tbz2

echo "End of $0"

