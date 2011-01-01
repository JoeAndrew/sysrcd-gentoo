# Parted 2.3 with patches from Ubuntu-20101205

EAPI="2"

WANT_AUTOMAKE="1.11"

inherit autotools eutils

DESCRIPTION="Create, destroy, resize, check, copy partitions and file systems"
HOMEPAGE="http://www.gnu.org/software/parted"
SRC_URI="mirror://gnu/${PN}/${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 ~mips ppc ppc64 s390 sh sparc x86"
IUSE="nls readline +debug selinux device-mapper"

# specific version for gettext needed
# to fix bug 85999
RDEPEND="
	>=sys-fs/e2fsprogs-1.27
	>=sys-libs/ncurses-5.2
	nls? ( >=sys-devel/gettext-0.12.1-r2 )
	readline? ( >=sys-libs/readline-5.2 )
	selinux? ( sys-libs/libselinux )
	device-mapper? ( || ( >=sys-fs/lvm2-2.02.45 sys-fs/device-mapper ) )
"
DEPEND="
	${RDEPEND}
	dev-util/pkgconfig
"

src_prepare() {
	# Remove tests known to FAIL instead of SKIP without OS/userland support
	sed -i libparted/tests/Makefile.am \
		-e 's|t3000-symlink.sh||g' || die "sed failed"
	sed -i tests/Makefile.am \
		-e '/t4100-msdos-partition-limits.sh/d' \
		-e '/t4100-dvh-partition-limits.sh/d' \
		-e '/t6000-dm.sh/d' || die "sed failed"

	# For upstream merging
	epatch "${FILESDIR}/preserve-hidden-parts.patch" || die 'patch'
	epatch "${FILESDIR}/update-ext4-code.patch" || die 'patch'
	epatch "${FILESDIR}/kfreebsd-gnu.patch" || die 'patch'
	epatch "${FILESDIR}/btrfs.patch" || die 'patch'
	epatch "${FILESDIR}/loop-limits.patch" || die 'patch'
	epatch "${FILESDIR}/freebsd-ufs.patch" || die 'patch'
	epatch "${FILESDIR}/zfs.patch" || die 'patch'
	epatch "${FILESDIR}/zero-length-devices.patch" || die 'patch'

	# Backported
	epatch "${FILESDIR}/sun-revert-disk-flag.patch" || die 'patch'
	epatch "${FILESDIR}/sun-raid-type-test-fix.patch" || die 'patch'
	epatch "${FILESDIR}/tiny-disk-constraint.patch" || die 'patch'
	
	# Ubuntu additions
	epatch "${FILESDIR}/gptsync.patch" || die 'patch'
	epatch "${FILESDIR}/loop-partitions.patch" || die 'patch'
	epatch "${FILESDIR}/udevadm-settle.patch" || die 'patch'
	epatch "${FILESDIR}/dmraid.patch" || die 'patch'
	epatch "${FILESDIR}/fix-dmraid-regression.patch" || die 'patch'

	eautoreconf
}

src_configure() {
	econf \
		$(use_with readline) \
		$(use_enable nls) \
		$(use_enable debug) \
		$(use_enable selinux) \
		$(use_enable device-mapper) \
		--disable-rpath \
		--disable-Werror || die "Configure failed"
}

src_test() {
	if use debug; then
		# Do not die when tests fail - some requirements are not
		# properly checked and should not lead to the ebuild failing.
		emake check
	else
		ewarn "Skipping tests because USE=-debug is set."
	fi
}

src_install() {
	emake install DESTDIR="${D}" || die "Install failed"
	dodoc AUTHORS BUGS ChangeLog NEWS README THANKS TODO
	dodoc doc/{API,FAT,USER.jp}
}
