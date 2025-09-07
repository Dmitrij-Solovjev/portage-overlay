# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${PV}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions BSD MIT ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="alltargets aarch64 armv7 i686 x86_64"

# Upstream scripts fetch LLVM/mingw-w64 sources during build.
RESTRICT="network-sandbox mirror"

S="${WORKDIR}/llvm-mingw-${PV}"

# Tools needed only at build-time
BDEPEND="
	dev-util/cmake
	dev-util/ninja
	dev-lang/python:3
	dev-vcs/git
	sys-devel/make
	sys-devel/patch
	sys-devel/autoconf
	sys-devel/automake
	sys-devel/libtool
	app-arch/xz-utils
	app-arch/unzip
	net-misc/curl
	virtual/pkgconfig
	sys-devel/bison
	sys-devel/flex
"

# The installed toolchain is self-contained under /opt, so no runtime deps.
RDEPEND=""

src_prepare() {
	default
	chmod +x build-*.sh || die
	chmod +x install-wrappers.sh prepare-cross-toolchain*.sh || die
}

src_compile() {
	export CC=${CC:-gcc}
	export CXX=${CXX:-g++}
	local out="${WORKDIR}/toolchain"
	einfo "Building llvm-mingw into ${out}"
	bash ./build-all.sh "${out}" || die "build-all.sh failed"

	# quick sanity: verify at least one target exists (aarch64 is the common case)
	if [[ ! -x "${out}/bin/aarch64-w64-mingw32-clang" ]] \
	   && [[ ! -x "${out}/bin/x86_64-w64-mingw32-clang" ]] \
	   && [[ ! -x "${out}/bin/i686-w64-mingw32-clang" ]] \
	   && [[ ! -x "${out}/bin/armv7-w64-mingw32-clang" ]]; then
		die "No target compilers found under ${out}/bin"
	fi
	export LLVMMINGW_OUT="${out}"
}

src_install() {
	local dest="/opt/llvm-mingw-${PV}"
	dodir "${dest}" || die
	cp -a "${LLVMMINGW_OUT}/." "${ED}${dest}" || die

	# Decide which target triples to expose on PATH via /usr/bin symlinks
	local triples=()
	use alltargets && triples+=(aarch64-w64-mingw32 armv7-w64-mingw32 i686-w64-mingw32 x86_64-w64-mingw32)
	use aarch64 && triples+=(aarch64-w64-mingw32)
	use armv7 && triples+=(armv7-w64-mingw32)
	use i686 && triples+=(i686-w64-mingw32)
	use x86_64 && triples+=(x86_64-w64-mingw32)
	if [[ ${#triples[@]} -eq 0 ]]; then
		ewarn "No USE targets selected; defaulting to aarch64"
		triples=(aarch64-w64-mingw32)
	fi

	# Create convenient symlinks for common tools
	local tool
	for t in "${triples[@]}"; do
		for tool in clang clang++ ar ranlib nm objdump windres dlltool lld lld-link as strip addr2line; do
			if [[ -x "${ED}${dest}/bin/${t}-${tool}" ]]; then
				dosym "/opt/llvm-mingw-${PV}/bin/${t}-${tool}" "/usr/bin/${t}-${tool}" || die
			fi
		done
	done

	einstalldocs
}

pkg_postinst() {
	elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV}"
	elog "Symlinks for selected triples were created under /usr/bin"
	elog "If you need different triples, rebuild with appropriate USE flags (aarch64 armv7 i686 x86_64 or alltargets)."
}

