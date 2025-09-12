# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 19 20 )
LLVM_OPTIONAL=1

inherit flag-o-matic cmake toolchain-funcs llvm-r1

DESCRIPTION="A fast usermode x86 and x86-64 emulator for Arm64 Linux"
HOMEPAGE="https://fex-emu.com"

JEMALLOC_HASH="ce24593018ca5d5af7e5661ceda9744e02b59f8f"
JEMALLOC_GLIBC_HASH="8436195ad5e1bc347d9b39743af3d29abee59f06"
CPP_OPTPARSE_HASH="9f94388a339fcbb0bc95c17768eb786c85988f6e"
ROBIN_MAP_HASH="d5683d9f1891e5b04e3e3b2192b5349dc8d814ea"

# for mingw_dlls
XXHASH_HASH="bbb27a5efb85b92a0486cf361a8635715a53f6ba"
FMT_HASH="20c8fdad0605a1627a3f6d15cad693a3fbe2ecbf"

# This need to be vendored since thunk generator does not support the latest version
VULKAN_HEADERS_HASH="cacef3039d277c448c89336290ec3937270b0996"

SRC_URI="
	https://github.com/FEX-Emu/jemalloc/archive/${JEMALLOC_HASH}.tar.gz -> jemalloc-${JEMALLOC_HASH}.tar.gz
	https://github.com/FEX-Emu/jemalloc/archive/${JEMALLOC_GLIBC_HASH}.tar.gz -> jemalloc-glibc-${JEMALLOC_GLIBC_HASH}.tar.gz
	https://github.com/Sonicadvance1/cpp-optparse/archive/${CPP_OPTPARSE_HASH}.tar.gz -> cpp-optparse-${CPP_OPTPARSE_HASH}.tar.gz
	https://github.com/FEX-Emu/robin-map/archive/${ROBIN_MAP_HASH}.tar.gz -> robin-map-${ROBIN_MAP_HASH}.tar.gz
	thunks? (
		https://github.com/KhronosGroup/Vulkan-Headers/archive/${VULKAN_HEADERS_HASH}.tar.gz -> Vulkan-Headers-${VULKAN_HEADERS_HASH}.tar.gz
	)
	https://github.com/FEX-Emu/${PN}/archive/refs/tags/${P}.tar.gz

	https://github.com/Cyan4973/xxHash/archive/${XXHASH_HASH}.tar.gz -> xxhash-${XXHASH_HASH}.tar.gz
	https://github.com/fmtlib/fmt/archive/${FMT_HASH}.tar.gz -> fmt-${FMT_HASH}.tar.gz
"

S="${WORKDIR}/${PN}-${P}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="-* ~arm64"
BDEPEND="
	llvm-core/clang
	llvm-core/llvm
	thunks? (
		!crossdev-toolchain? (
			sys-devel/x86_64-multilib-toolchain
		)
		$(llvm_gen_dep '
			llvm-core/clang:${LLVM_SLOT}=
			llvm-core/llvm:${LLVM_SLOT}=
		')
	)
	mingw_dlls? (
		llvm-core/llvm-mingw
	)
"
RDEPEND="
	dev-libs/xxhash
	>=dev-libs/libfmt-11.0.2:=
	qt6? (
		dev-qt/qtbase:6[gui,wayland(-),widgets,X(-)]
		dev-qt/qtdeclarative:6
	)
	thunks? (
		x11-libs/libX11
		x11-libs/libdrm
		dev-libs/wayland
		media-libs/alsa-lib
		media-libs/libglvnd
		x11-libs/libxcb
	)
	app-emulation/fex-rootfs-gentoo
"
DEPEND="
	>=sys-kernel/linux-headers-6.14
	${RDEPEND}

"

PATCHES="
	${FILESDIR}/${PN}-2503-unvendor-drm-headers.patch
	${FILESDIR}/${PN}-2507-thunks-toolchain-paths.patch
	${FILESDIR}/${PN}-2503-thunkgen-gcc-install-dir.patch
	${FILESDIR}/${PN}-2508.1-custom-hangover.patch
"

IUSE="crossdev-toolchain +fexconfig +qt6 thunks mingw_dlls"

REQUIRED_USE="
	crossdev-toolchain? ( thunks )
	fexconfig? ( qt6 )
	thunks? ( ${LLVM_REQUIRED_USE} )
"

# директория внутри этапа установки, куда положим dll внутри ED
FEX_DLL_DIR="/usr/lib/fex-dll-libs"

my-test-flag-PROG() {
	local comp=$1
	local lang=$2
	shift 2

	if [[ -z $1 ]]; then
		return 1
	fi

	if ! type -p ${comp[0]} >/dev/null; then
		return 1
	fi

	local in_src in_ext cmdline_extra=()
	case "${lang}" in
		c)
			in_ext='c'
			in_src='int main(void) { return 0; }'
			cmdline_extra+=(-xc -c)
			;;
		c++)
			in_ext='cc'
			in_src='int main(void) { return 0; }'
			cmdline_extra+=(-xc++ -c)
			;;
	esac
	local test_in=${T}/test-flag.${in_ext}
	local test_out=${T}/test-flag.exe

	printf "%s\n" "${in_src}" > "${test_in}" || die "Failed to create '${test_in}'"
	local cmdline=(
		"${comp[@]}"
		-Werror
		"$@"
		"${cmdline_extra[@]}"
		"${test_in}" -o "${test_out}"
	)

	"${cmdline[@]}" &>/dev/null
}

my-test-flags-PROG() {
	local comp=$1
	local lang=$2
	local flags=()
	local x

	shift 2

	while (( $# )); do
		case "$1" in
			--param|-B)
				if my-test-flag-PROG ${comp} ${lang} "$1" "$2"; then
					flags+=( "$1" "$2" )
				fi
				shift 2
				;;
			*)
				if my-test-flag-PROG ${comp} ${lang} "$1"; then
					flags+=( "$1" )
				fi
				shift 1
				;;
		esac
	done

	echo "${flags[*]}"
	[[ ${#flags[@]} -gt 0 ]]
}

my-filter-var() {
	local f x var=$1 new=()
	shift

	for f in ${!var} ; do
		for x in "$@" ; do
			[[ ${f} == ${x} ]] && continue 2
		done
		new+=( "${f}" )
	done
	export ${var}="${new[*]}"
}

THUNK_INC_DIR="${WORKDIR}/thunk-include"

find_compiler() {
	(
		pattern="$1"
		shift
		shopt -s nullglob
		IFS=: read -r -a paths <<<"$PATH"
		for dir in "${paths[@]}"; do
			for cand in "$dir"/$pattern; do
				"${cand}" -o /dev/null -x c "$@" - 2>/dev/null >/dev/null <<<'int main(){}' && echo "${cand#/${dir}}" && return 0
			done
		done
		return 1
	)
}

pkg_setup() {
	use thunks && llvm-r1_pkg_setup
}

pkg_pretend() {
	[[ ${MERGE_TYPE} == binary ]] && return
	use thunks || return
	use crossdev-toolchain || return
	errmsg="Unable to find a working ARCH compiler on your system. You need to install one using crossdev."
	find_compiler 'x86_64*-linux-gnu-gcc' >/dev/null || die "${errmsg/ARCH/x86_64}"
	find_compiler 'i?86*-linux-gnu-gcc' >/dev/null || find_compiler 'x86_64*-linux-gnu-gcc' -m32 >/dev/null || die "${errmsg/ARCH/i686}"
	
	# If user asked to build windows dlls, ensure llvm-mingw toolchain is available
	if use mingw_dlls; then
		local mm_err="mingw dll build requested (mingw_dlls USE), but llvm-mingw toolchain not found in PATH. Install llvm-mingw and add its bin to PATH."
		type -P arm64ec-w64-mingw32-clang >/dev/null 2>&1 || type -P aarch64-w64-mingw32-clang >/dev/null 2>&1 || die "${mm_err}"
	fi
}

src_unpack() {
	default
	local -A deps=(
		jemalloc "jemalloc-${JEMALLOC_HASH}"
		jemalloc_glibc "jemalloc-${JEMALLOC_GLIBC_HASH}"
		robin-map "robin-map-${ROBIN_MAP_HASH}"
		fmt "fmt-${FMT_HASH}"
		xxhash "xxHash-${XXHASH_HASH}"
	)
	use thunks && deps[Vulkan-Headers]="Vulkan-Headers-${VULKAN_HEADERS_HASH}"
	for dep in "${!deps[@]}"; do
		rmdir "${S}/External/${dep}" || die
		mv "${WORKDIR}/${deps[${dep}]}" "${S}/External/${dep}"
	done
	rmdir "${S}/Source/Common/cpp-optparse" || die
	mv "${WORKDIR}/cpp-optparse-${CPP_OPTPARSE_HASH}" "${S}/Source/Common/cpp-optparse" || die
}

THUNK_HEADERS="
	GL
	EGL
	GLES
	GLES2
	GLES3
	KHR
	glvnd
	wayland-client-core.h
	wayland-client-protocol.h
	wayland-client.h
	wayland-cursor.h
	wayland-egl-backend.h
	wayland-egl-core.h
	wayland-egl.h
	wayland-server-core.h
	wayland-server-protocol.h
	wayland-server.h
	wayland-util.h
	wayland-version.h
	X11
	libdrm
	libsync.h
	xf86drm.h
	xf86drmMode.h
	alsa
	xcb
"

src_prepare() {
	cmake_src_prepare
	sed -i -e "s:__REPLACE_ME_WITH_HEADER_DIR__:${THUNK_INC_DIR}:" ThunkLibs/GuestLibs/CMakeLists.txt || die
	mkdir "${THUNK_INC_DIR}" || die
	for header in $THUNK_HEADERS; do
		cp -a "${BROOT}/usr/include/${header}" "${THUNK_INC_DIR}/${header}" || die
	done
}

src_configure() {
	if ! tc-is-clang ; then
		AR=llvm-ar
		CC=clang
		CXX=clang++
		NM=llvm-nm
		RANLIB=llvm-ranlib
		STRIP=llvm-strip

		strip-unsupported-flags
	fi

	local mycmakeargs=(
		-DBUILD_TESTS=False
		-DENABLE_CCACHE=False
		-DENABLE_LTO=$(if tc-is-lto; then echo True; else echo False; fi)
		-DBUILD_FEXCONFIG=$(usex fexconfig)
		-DBUILD_THUNKS=$(usex thunks)
		-DENABLE_CLANG_THUNKS=False
	)

	if use thunks; then
		oldpath="${PATH}"
		use crossdev-toolchain || PATH="${BROOT}/usr/lib/x86_64-multilib-toolchain/bin:${PATH}"
		local x64_cc="$(find_compiler 'x86_64*-linux-gnu-gcc' || die)"
		local x86_cc
		if x86_cc="$(find_compiler 'x86_64*-linux-gnu-gcc' -m32)"; then
			x86_cc="${x86_cc} -m32"
		else
			x86_cc="$(find_compiler 'i?86*-linux-gnu-gcc' || die)"
		fi

		sed -i -e "s:__REPLACE_ME_WITH_C_COMPILER__:${x64_cc}:" Data/CMake/toolchain_x86_64.cmake || die
		sed -i -e "s:__REPLACE_ME_WITH_C_COMPILER__:${x86_cc}:" Data/CMake/toolchain_x86_32.cmake || die
		sed -i -e "s:__REPLACE_ME_WITH_CXX_COMPILER__:${x64_cc/linux-gnu-gcc/linux-gnu-g++}:" Data/CMake/toolchain_x86_64.cmake || die
		sed -i -e "s:__REPLACE_ME_WITH_CXX_COMPILER__:${x86_cc/linux-gnu-gcc/linux-gnu-g++}:" Data/CMake/toolchain_x86_32.cmake || die

		export X86_CFLAGS="$(my-test-flags-PROG ${x64_cc/%gcc/cc} c ${CFLAGS} ${LDFLAGS})"
		export X86_CXXFLAGS="$(my-test-flags-PROG ${x64_cc/%gcc/c++} c++ ${CXXFLAGS} ${LDFLAGS})"
		export X86_LDFLAGS="$(my-test-flags-PROG ${x64_cc/%gcc/cc} c ${LDFLAGS})"

		my-filter-var X86_CFLAGS '-flto*' -fwhole-program-vtables '-fsanitize=cfi*'
		my-filter-var X86_CXXFLAGS '-flto*' -fwhole-program-vtables '-fsanitize=cfi*'
		mycmakeargs+=(
			-DX86_CFLAGS="${X86_CFLAGS}"
			-DX86_CXXFLAGS="${X86_CXXFLAGS}"
			-DX86_LDFLAGS="${X86_LDFLAGS}"
		)

		tc-export CC CXX LD AR NM OBJDUMP RANLIB PKG_CONFIG
	fi

	cmake_src_configure
}

build_win_dlls() {
	use mingw_dlls || return

	einfo "Building Windows DLLs (arm64ec & wow64) via llvm-mingw"

	# Найдём llvm-mingw bin (ищем несколько возможных мест)
	local mm_bin mm_root mm_arch_libdir
	for candidate in \
		"$(type -P arm64ec-w64-mingw32-clang 2>/dev/null)" \
		"$(type -P aarch64-w64-mingw32-clang 2>/dev/null)" \
		"${HOME}/llvm-mingw/bin/arm64ec-w64-mingw32-clang" \
		"${HOME}/llvm-mingw/bin/aarch64-w64-mingw32-clang" \
		"/usr/lib/llvm-mingw/"*/bin/arm64ec-w64-mingw32-clang \
		"/usr/lib/llvm-mingw/"*/bin/aarch64-w64-mingw32-clang \
		"/opt/llvm-mingw/bin/arm64ec-w64-mingw32-clang" \
		"/opt/llvm-mingw/bin/aarch64-w64-mingw32-clang"
	do
		# expand glob candidate and test
		local path
		for path in ${candidate}; do
			[[ -x "${path}" ]] || continue
			mm_bin="$(dirname "${path}")"
			break 2
		done
	done

	[[ -n "${mm_bin}" ]] || die "llvm-mingw toolchain not found (looked for arm64ec/aarch64 clang). Install llvm-mingw and add its bin to PATH."

	# временно добавить llvm-mingw в PATH, чтобы cmake нашёл нужный clang/ld/lld
	local old_PATH="${PATH}"
	PATH="${mm_bin}:${PATH}"

	# базовый корень (например /usr/lib/llvm-mingw/20250826)
	mm_root="${mm_bin%/bin}"

	# Попробуем найти архитектурную папку с либами (aarch64-w64-mingw32 или arm64ec-w64-mingw32)
	if [[ -d "${mm_root}/aarch64-w64-mingw32/lib" ]]; then
		mm_arch_libdir="${mm_root}/aarch64-w64-mingw32/lib"
	elif [[ -d "${mm_root}/arm64ec-w64-mingw32/lib" ]]; then
		mm_arch_libdir="${mm_root}/arm64ec-w64-mingw32/lib"
	elif [[ -d "${mm_root}/lib" ]]; then
		mm_arch_libdir="${mm_root}/lib"
	else
		# fallback: попробуем любые lib-папки внутри mm_root
		mm_arch_libdir="$(find "${mm_root}" -maxdepth 2 -type d -name 'lib*' | head -n1 || true)"
	fi

	[[ -n "${mm_arch_libdir}" ]] || die "Failed to locate llvm-mingw lib directory under ${mm_root}"

	einfo "Using llvm-mingw bin: ${mm_bin}, arch libdir: ${mm_arch_libdir}"

	# Проверка, что vendored externals присутствуют
	[[ -d "${S}/External/xxhash/cmake_unofficial" ]] || die "Missing vendored xxhash at ${S}/External/xxhash/cmake_unofficial"
	[[ -f "${S}/External/fmt/CMakeLists.txt" ]] || die "Missing vendored fmt at ${S}/External/fmt/CMakeLists.txt"

	# выходная директория внутри пакета (ED)
	local outdir="${ED}/${FEX_DLL_DIR}"
	mkdir -p "${outdir}" || die "Failed to create ${outdir}"

	# helper: configure+build+copy для конкретной тройки и таргета
	_build_one() {
		local triple="$1"; local target="$2"; local buildname="$3"
		local builddir="${WORKDIR}/${buildname}"

		cmake -E make_directory "${builddir}" || die "mkdir ${builddir}"
		(
			cd "${builddir}" || die

			# Собираем список локальных .a, которые нужно принудительно пройти группой.
			# Сюда добавляем наиболее критичные - xxhash, fmt, libntdll_ex и потенциальные FEX артефакты.
			local GROUP_LIBS=""
			local cand
			# общие кандидаты (могут не существовать в момент конфигурации, поэтому проверяем)
			for cand in \
				"${S}/External/xxhash/cmake_unofficial/libxxhash.a" \
				"${S}/External/fmt/libfmt.a" \
				"${S}/Source/Windows/libntdll_ex.a" \
				"${S}/Source/Common/libCommon.a" \
				"${S}/FEXCore/Source/libFEXCore_Base.a" \
				"${builddir}/FEXCore/Source/libFEXCore_Base.a" \
				"${builddir}/FEXCore/Source/libJemallocLibs.a" \
				"${builddir}/FEXCore/Source/libFEXCore_Base.a"
			do
				[[ -f "${cand}" ]] && GROUP_LIBS="${GROUP_LIBS} ${cand}"
			done

			# Попробуем добавить libgcc из toolchain, если есть
			if [[ -f "${mm_arch_libdir}/libgcc.a" ]]; then
				GROUP_LIBS="${GROUP_LIBS} ${mm_arch_libdir}/libgcc.a"
			fi

			# Уберём возможные дубли и нач/конец пустого списка корректно обработаем ниже
			# Формируем флаги линкера
			local start_group_flag="" end_group_flag=""
			[[ -n "${GROUP_LIBS// /}" ]] && start_group_flag="-Wl,--start-group ${GROUP_LIBS} -Wl,--end-group"

			# Конфигурируем cmake для mingw-цели
			cmake "${S}" \
				-DCMAKE_BUILD_TYPE=RelWithDebInfo \
				-DCMAKE_TOOLCHAIN_FILE="${S}/Data/CMake/toolchain_mingw.cmake" \
				-DMINGW_TRIPLE="${triple}" \
				-DBUILD_TESTS=False \
				-G Ninja \
				-DCMAKE_CXX_FLAGS="-stdlib=libc++ ${CXXFLAGS}" \
				-DCMAKE_C_FLAGS="${CFLAGS}" \
				-DCMAKE_SHARED_LINKER_FLAGS="-L${mm_arch_libdir} ${start_group_flag} -lc++ -lc++abi -lunwind" \
				-DCMAKE_EXE_LINKER_FLAGS="-L${mm_arch_libdir} -lc++ -lc++abi -lunwind" || die "cmake config for ${triple}"

			# Собираем таргет
			cmake --build . --target "${target}" --config RelWithDebInfo || die "cmake build ${target}"
		)

		# Copy resulting DLL into ${outdir}
		local dll_paths=(
			"${builddir}/Bin/lib${target}.dll"
			"${builddir}/Bin/${target}.dll"
			"${builddir}/Bin/"*.dll
			"${builddir}/lib${target}.dll"
		)
		local found=0
		for cand in "${dll_paths[@]}"; do
			for f in ${cand}; do
				[[ -f "${f}" ]] || continue
				cp -a "${f}" "${outdir}/" || die "Failed to copy ${f} -> ${outdir}"
				found=1
			done
			(( found )) && break
		done

		if [[ ${found} -eq 0 ]]; then
			ewarn "No dll found for ${target} in ${builddir}/Bin/. Inspect builddir."
			# не фаталим — но сообщаем
		else
			einfo "Installed built dll(s) for ${target} into ${outdir}"
		fi
	}

	# build arm64ec (арм64 ec)
	_build_one "arm64ec-w64-mingw32" "arm64ecfex" "build_ec"

	# build wow64 / pe (aarch64)
	_build_one "aarch64-w64-mingw32" "wow64fex" "build_pe"

	# restore PATH
	PATH="${old_PATH}"

	einfo "Windows DLL build finished. DLLs (если были собраны) лежат в ${outdir}"
}


src_install() {
	cmake_src_install
	tc-is-lto && dostrip -x /usr/lib/libFEXCore.a
	rm "${ED}/usr/share/man/man1/FEX.1.gz" || die
	if use thunks; then
		dostrip -x /usr/share/fex-emu/GuestThunks{,_32}/
		PATH="${oldpath}"
	fi
	
	build_win_dlls
}

pkg_postinst() {
	if [[ "$(getconf PAGESIZE)" -ne 4096 ]] && ! type -P "${EPREFIX}/usr/bin/muvm" >/dev/null ; then
		ewarn "Your system page size is not 4096 and as such"
		ewarn "you need to install app-emulation/muvm or a similar solution"
		ewarn "for FEX to work on your machine."
	fi
}
