# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake toolchain-funcs optfeature

DESCRIPTION="Box64 - Linux Userspace x86_64 Emulator with a twist, targeted at ARM64, RV64 and LoongArch Linux devices"
HOMEPAGE="https://box86.org"
SRC_URI="https://github.com/ptitSeb/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~arm64 ~ppc64"
IUSE="static wowbox64"

# BOX64_TARGET can be set to one of the following values:
# - RK3588
# - RK3399
# - RPI3
# - RPI4
# - RPI5
#
# Example usage:
#   BOX64_TARGET="RK3588" emerge app-emulation/box64
#
# If BOX64_TARGET is not set, the default is the system's architecture (${ARCH}).

pkg_setup() {
	if [[ $(tc-endian) == big ]]; then
		eerror "box86/box64 sadly does not support big endian systems."
		die "big endian not supported!"
	fi

	if [[ ${CHOST} != *gnu* || ${CHOST} != *linux* ]]; then
		eerror "box86/64 requires a glibc and a linux system. Musl support is possible, upstream welcomes PRs!"
		die "Not a GNU+Linux system"
	fi
}

src_configure() {
	local -a mycmakeargs=(
		-DNOGIT=1
		-DARM_DYNAREC=0
		-DRV64_DYNAREC=0
	)
	
	case "${BOX64_TARGET}" in
        "RK3588")
            mycmakeargs+=(
                -D RK3588=1
                -DBAD_SIGNAL=ON
            )
            ;;
        "RK3399")
            mycmakeargs+=(-D RK3399=1)
            ;;
        "RPI3")
            mycmakeargs+=(-D RPI3ARM64=1)
            ;;
        "RPI4")
            mycmakeargs+=(-D RPI4ARM64=1)
            ;;
        "RPI5")
            mycmakeargs+=(-D RPI5ARM64=1)
            ;;
        *)
            # Default case is to use system's architecture without error
            ;;
    	esac

	(use arm || use arm64) && mycmakeargs+=( -DARM64=1 -DARM_DYNAREC=1 )
	use riscv && mycmakeargs+=( -DRV64=1 -DRV64_DYNAREC=1 )
	use ppc64 && mycmakeargs+=( -DPPC64LE=1 )
	use loong && mycmakeargs+=( -DLARCH64=1 )
	use amd64 && mycmakeargs+=( -DLD80BITS=1 -DNOALIGN=1 )
	use static && mycmakeargs+=( -DSTATICBUILD=1 )
	use wowbox64 && mycmakeargs+=( -DWOW64=ON )

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# ------------------------------------------------------------
	# Install wowbox64 (Windows/Mingw) artifacts if they were built
	# - Some builds produce wowbox64.dll and import-libs (.a/.lib) in the
	#   sub-build directory (wowbox64-prefix/src/wowbox64-build/).
	# - We will detect those artifacts in ${WORKDIR} and install them into
	#   ${D}/usr/lib/box64-x86_64-linux-gnu/ so box64 can use them at runtime.
	# ------------------------------------------------------------

	local wow_install_dir="${D}/usr/lib/box64-x86_64-linux-gnu"
	dodir "${wow_install_dir}" || true

	# copy any relevant wow/wowbox64 files from the build tree
	if command -v find >/dev/null 2>&1; then
		find "${WORKDIR}" -type f \
			\( -iname 'wowbox64.*' -o -iname 'wow64.*' -o -iname '*.dll' -o -iname '*.a' -o -iname '*.lib' -o -iname '*.so' \) -print0 2>/dev/null | \
		while IFS= read -r -d '' _f; do
			case "${_f}" in
				*.dll|*.a|*.lib|*.so)
					doins "${_f}" "${wow_install_dir}/"
					;;
			esac
		done
	fi

	# ------------------------------------------------------------
	# Selective strip: only strip native AArch64 files. Skips x86_64/PE/etc.
	# This avoids "cannot determine file format" from cross-strip tools.
	# ------------------------------------------------------------
	if command -v readelf >/dev/null 2>&1; then
		find "${D}" -type f -print0 | while IFS= read -r -d '' f; do
			[ -f "${f}" ] || continue
			# skip docs
			case "${f}" in
				*/share/doc/*|*/usr/share/doc/*) continue ;; 
			esac
			if readelf -h "${f}" >/dev/null 2>&1; then
				machine=$(readelf -h "${f}" | awk -F: '/Machine:/ {gsub(/^ +| +$/, "", $2); print $2}')
				case "${machine}" in
					*AArch64*|*Advanced\ ARM\ AArch64*|*ARM\ aarch64*)
						${STRIP:-strip} --strip-unneeded "${f}" 2>/dev/null || true
						;;
					*)
						# non-native: do not touch
						;;
				esac
			fi
		done
	else
		ewarn "readelf not found: skipping selective strip to avoid corrupting cross-arch files."
	fi
}

pkg_postinst() {
	optfeature "OpenGL for GLES devices" \
		"media-libs/gl4es"

	if [[ ${ED} == 1 ]]; then
		cat << 'EOF'
Note about box64 packaging:

This package may build and install x86_64 runtime libraries and optional
WowBox64 artifacts into:
  /usr/lib/box64-x86_64-linux-gnu/

Those files are intended for the emulated x86_64 environment and are NOT
native ARM64 binaries. QA tools (strip/scanelf) may show warnings such as
"Невозможно определить формат входного файла" or "Unresolved soname
dependencies" for these files; this is expected and benign. If you do not
want the WowBox64/Mingw part, rebuild with USE="-wowbox64".
EOF
	fi
}

