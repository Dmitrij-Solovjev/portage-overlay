# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions BSD MIT ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="alltargets aarch64 armv7 i686 x86_64"

RESTRICT="network-sandbox mirror"

S="${WORKDIR}/llvm-mingw-${PV}"

BDEPEND="
	dev-build/autoconf
	dev-build/automake
	dev-build/cmake
	dev-build/ninja
	dev-lang/python
	dev-vcs/git
	sys-devel/patch
	dev-build/libtool
	app-arch/xz-utils
	app-arch/unzip
	net-misc/curl
	virtual/pkgconfig
	sys-devel/bison
	sys-devel/flex
"

src_compile() {

	local out="${WORKDIR}/toolchain"
	local native="${WORKDIR}/native-tools"
	mkdir -p "${native}"
	export PATH="${CC%/*}:${CXX%/*}:$PATH"

	for arch in "${arches[@]}"; do
		einfo "Building llvm-mingw for ${arch}"
		# нужно из-за бага build-cross-tools.sh
		export  PYTHON=0
		bash ./build-cross-tools.sh "${native}" "${out}" "${arch}" \
			--disable-lldb --disable-lldb-mi --disable-clang-tools-extra \
			|| die "build-cross-tools.sh failed for ${arch}"
	done

	export LLVMMINGW_OUT="${out}"
}

src_install() {
	local dest="/usr/lib/llvm-mingw/${PV}"
	local ctools=(clang clang++ ar ranlib nm objdump windres dlltool lld lld-link as strip addr2line)

	# установить toolchain
	dodir "${dest}"
	cp -a "${LLVMMINGW_OUT}/." "${ED}${dest}" || die

	# фронтенды
	local triples=()
	if use alltargets; then
		triples+=(aarch64-w64-mingw32 armv7-w64-mingw32 i686-w64-mingw32 x86_64-w64-mingw32)
	else
		use aarch64 && triples+=(aarch64-w64-mingw32)
		use armv7   && triples+=(armv7-w64-mingw32)
		use i686    && triples+=(i686-w64-mingw32)
		use x86_64  && triples+=(x86_64-w64-mingw32)
	fi
	[[ ${#triples[@]} -eq 0 ]] && triples=(x86_64-w64-mingw32)

	for triple in "${triples[@]}"; do
		for tool in "${ctools[@]}"; do
			if [[ -x "${ED}${dest}/bin/${triple}-${tool}" ]]; then
				dosym "${dest}/bin/${triple}-${tool}" "/usr/bin/${triple}-${tool}"
			fi
		done
	done

	# документация
	if [[ -d "${ED}${dest}/share/doc" ]]; then
		dodoc -r "${ED}${dest}"/share/doc/*
		rm -rf "${ED}${dest}"/share/doc || die
	fi

	# чистка пустых каталогов
	find "${ED}${dest}" -type d -empty -delete 2>/dev/null
}

pkg_postinst() {
	elog "Toolchain installed to /usr/lib/llvm-mingw/${PV}"
	elog "Cross frontends are available in /usr/bin with target prefixes"
	elog "Default target is x86_64-w64-mingw32 if none selected"
}

