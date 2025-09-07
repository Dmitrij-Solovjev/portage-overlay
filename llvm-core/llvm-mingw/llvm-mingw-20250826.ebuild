# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions BSD MIT ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+native alltargets aarch64 armv7 i686 x86_64"

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
	export CC=${CC:-gcc}
	export CXX=${CXX:-g++}
	local out="${WORKDIR}/toolchain"
	local native="${EPREFIX}/usr"
	local arches=()

	# определить таргеты
	if use alltargets; then
		arches=(aarch64 armv7 i686 x86_64)
	else
		use aarch64 && arches+=(aarch64)
		use armv7   && arches+=(armv7)
		use i686    && arches+=(i686)
		use x86_64  && arches+=(x86_64)
	fi

	# если пусто → берём native
	if [[ ${#arches[@]} -eq 0 ]]; then
		if use native; then
			arches=("native")
		else
			die "No targets selected. Enable at least one of: native, aarch64, armv7, i686, x86_64, alltargets"
		fi
	fi

	# сборка по списку
	for arch in "${arches[@]}"; do
		einfo "Building llvm-mingw for ${arch}"
		if [[ ${arch} == "native" ]]; then
			bash ./build-native-tools.sh "${out}" \
				--disable-lldb --disable-lldb-mi --disable-clang-tools-extra \
				|| die "build-native-tools.sh failed"
		else
			bash ./build-cross-tools.sh "${native}" "${out}" "${arch}" \
				--disable-lldb --disable-lldb-mi --disable-clang-tools-extra \
				|| die "build-cross-tools.sh failed for ${arch}"
		fi
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

	# если ничего не выбрано → нативный тулчейн без префиксов
	if [[ ${#triples[@]} -eq 0 ]] && use native; then
		for tool in "${ctools[@]}"; do
			if [[ -x "${ED}${dest}/bin/${tool}" ]]; then
				dosym "${dest}/bin/${tool}" "/usr/bin/${tool}"
			fi
		done
	else
		for triple in "${triples[@]}"; do
			for tool in "${ctools[@]}"; do
				if [[ -x "${ED}${dest}/bin/${triple}-${tool}" ]]; then
					dosym "${dest}/bin/${triple}-${tool}" "/usr/bin/${triple}-${tool}"
				fi
			done
		done
	fi

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
	if use native; then
		elog "Native frontends are available in /usr/bin without target prefix"
	else
		elog "Cross frontends are available in /usr/bin with target prefixes"
	fi
}

