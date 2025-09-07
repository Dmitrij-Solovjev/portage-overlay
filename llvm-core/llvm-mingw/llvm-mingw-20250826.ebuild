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
	export CC=${CC:-gcc}
	export CXX=${CXX:-g++}
	local toolchain_dir="${WORKDIR}/toolchain"
	local native_dir="${WORKDIR}/native"
	einfo "Building llvm-mingw toolchain (selected targets only) into ${toolchain_dir}"
	mkdir -p "${toolchain_dir}" "${native_dir}" || die

	# Определяем список архитектур по USE-флагам
	local archs=()
	use alltargets && archs=(aarch64 armv7 i686 x86_64)
	use aarch64   && archs+=(aarch64)
	use armv7     && archs+=(armv7)
	use i686      && archs+=(i686)
	use x86_64    && archs+=(x86_64)
	[[ ${#archs[@]} -eq 0 ]] && archs=(aarch64)  # по умолчанию

	# Запускаем build-cross-tools.sh для каждой архитектуры
	for arch in "${archs[@]}"; do
		einfo "Building target ${arch}-w64-mingw32"
		local out_dir="${toolchain_dir}/${arch}"
		local native_subdir="${native_dir}/${arch}"
		mkdir -p "${out_dir}" "${native_subdir}" || die
		# из-за бага в build-cross-tools.sh
		export PYTHON=0
		./build-cross-tools.sh "${native_subdir}" "${out_dir}" "${arch}"
	done

	# Проверяем, что хотя бы один компилятор собран
	local found=0
	for arch in "${archs[@]}"; do
		if [[ -x "${toolchain_dir}/${arch}/bin/${arch}-w64-mingw32-clang" ]]; then
			found=1; break
		fi
	done
	[[ $found -eq 0 ]] && die "No target compilers built"

	export LLVMMINGW_OUT="${toolchain_dir}"
}

src_install() {
	local dest="/usr/lib/llvm-mingw/${PV}"
	local ctools=(clang clang++ ar ranlib nm objdump windres dlltool lld lld-link as strip addr2line)
	dodir "${dest}"

	# Копируем файлы из каждой архитектуры в общую директорию
	for arch in "${archs[@]}"; do
		cp -a "${LLVMMINGW_OUT}/${arch}/." "${ED}${dest}" || die
	done

	# Создаём симлинки для frontends по каждому триплету
	for arch in "${archs[@]}"; do
		local trip="${arch}-w64-mingw32"
		for tool in "${ctools[@]}"; do
			if [[ -x "${ED}${dest}/bin/${trip}-${tool}" ]]; then
				dosym "${dest}/bin/${trip}-${tool}" "/usr/bin/${trip}-${tool}"
			fi
		done
	done

	# Убираем документацию из пакета
	if [[ -d "${ED}${dest}/share/doc" ]]; then
		dodoc -r "${ED}${dest}/share/doc"/*
		rm -rf "${ED}${dest}/share/doc" || die
	fi

	# Очистка пустых директорий
	find "${ED}${dest}" -type d -empty -delete 2>/dev/null
}

pkg_postinst() {
	local dest="/usr/lib/llvm-mingw/${PV}"
	elog "Toolchain installed to ${dest}"
	elog "Frontends are available in /usr/bin with target prefixes"
	elog "Target files (libraries/headers) are in ${dest}/<target>"
}

