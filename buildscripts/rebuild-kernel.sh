#!/bin/bash

imagename="$1"

case ${imagename} in
	rescue32)
		KERTYPE='std'
		ARCHNAME='i?86'
		LIBDIR='lib'
		;;
	rescue64)
		KERTYPE='std'
		ARCHNAME='amd64'
		LIBDIR='lib64'
		;;
	*)
		echo "$0: invalid argument"
		exit 1
		;;
esac

# Bazz note: I've gone and put x86 stuff hard into the buildscript. This
# may have messed up the Sparc stuff, but there is no Sparc buildscripts
# available, and I can't test that stuff anyways. oh well
(cd /worksrc/sysresccd-src/mainfiles ; nice catalyst -c catalyst.conf-x86 -a -f sysresccd-krnl-stage2-${imagename}.spec)
sleep 2

targetdir="/worksrc/sysresccd-bin/overlay-squashfs-x86/${LIBDIR}/modules"
rootkernel=$(ls -d /var/tmp/catalyst/builds/default/livecd-stage2-${ARCHNAME}-krnl/boot)
rootmodule=$(ls -d /var/tmp/catalyst/tmp/default/livecd-stage2-${ARCHNAME}-krnl/lib/modules)
kervertemp=$(ls -d ${rootmodule}/*${KERTYPE}*-${ARCHNAME})
kerversion=${kervertemp##*/}

echo "rootkernel=[${rootkernel}]"
echo "rootmodule=[${rootmodule}]"
echo "kerversion=[${kerversion}]"

if [ -z "${rootkernel}" ] || [ -z "${rootmodule}" ] || [ -z "${rootmodule}" ]
then
	echo "ERROR: invalid variables"
	exit 1
fi

echo "cp ${rootkernel}/${imagename}* /worksrc/sysresccd-bin/kernels-x86/"
cp ${rootkernel}/${imagename}* /worksrc/sysresccd-bin/kernels-x86/

mkdir -p ${targetdir}
echo "(cd ${rootmodule} ; tar cfj ${targetdir}/${kerversion}.tar.bz2 ${kerversion})"
(cd ${rootmodule} ; tar cfj ${targetdir}/${kerversion}.tar.bz2 ${kerversion})

#mkdir -p /var/tmp/EMBEDDEDINIT
#rsync -ax /worksrc/catalyst/tmp/default/livecd-stage2-*/etc/kernels/initramfs-*.cpio* /var/tmp/EMBEDDEDINIT/

