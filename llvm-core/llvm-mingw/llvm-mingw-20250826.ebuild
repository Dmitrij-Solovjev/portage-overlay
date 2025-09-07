# Copyright 2025 Gentoo Authors
# SPDX-License-Identifier: GPL-2.0

EAPI=8

DESCRIPTION="llvm-mingw: a LLVM/Clang/LLD based mingw-w64 toolchain (prebuilt installer-style ebuild template)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
# Use GitHub tag archive (works reliably):
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="aarch64 x86_64 i686 alltargets"

DEPEND="app-arch/xz-utils"
RDEPEND=""

src_unpack() {
    unpack ${A}
    # GitHub tag archives unpack into a single subdir 'llvm-mingw-${PV}'.
    if [[ -d "${WORKDIR}/llvm-mingw-${PV}" ]]; then
        mv "${WORKDIR}/llvm-mingw-${PV}"/* "${WORKDIR}/"
        rmdir "${WORKDIR}/llvm-mingw-${PV}" || true
    fi
}

src_prepare() {
    default
    find . -exec touch -t 198001010000 {} + || true
}

src_install() {
    # Install into /opt/llvm-mingw-${PV} inside the image root
    local install_prefix="/opt/llvm-mingw-${PV}"
    # dodir expects a path as seen on the target system (it creates ${D}${path})
    dodir "${install_prefix}"

    # Copy all unpacked files into the image under ${D}${install_prefix}
    cp -a . "${D}${install_prefix}/"

    # Fix permissions for shipped binaries
    if [[ -d "${D}${install_prefix}/bin" ]]; then
        find "${D}${install_prefix}/bin" -type f -exec chmod 0755 {} + || true
    fi

    # Known triple names
    local -a triples=("x86_64-w64-mingw32" "aarch64-w64-mingw32" "i686-w64-mingw32")

    local expose_all=0
    if use alltargets; then
        expose_all=1
    fi

    for t in "${triples[@]}"; do
        case "${t}" in
            x86_64-w64-mingw32)
                if ! use x86_64 && [[ ${expose_all} -eq 0 ]]; then
                    continue
                fi
                ;;
            aarch64-w64-mingw32)
                if ! use aarch64 && [[ ${expose_all} -eq 0 ]]; then
                    continue
                fi
                ;;
            i686-w64-mingw32)
                if ! use i686 && [[ ${expose_all} -eq 0 ]]; then
                    continue
                fi
                ;;
        esac

        for tool in clang clang++ clang-cl clangd lld lldb ar as nm ranlib strip objcopy objdump; do
            local src="${install_prefix}/bin/${t}-${tool}"  # target-system path
            local dst="/usr/bin/${t}-${tool}"
            if [[ -x "${D}${src}" ]]; then
                dodir "$(dirname "${dst}")"
                dosym "${src}" "${dst}"
            fi
        done

        # generic cc/c++ wrappers
        local src_cc="${install_prefix}/bin/${t}-clang"
        local src_cxx="${install_prefix}/bin/${t}-clang++"
        if [[ -x "${D}${src_cc}" ]]; then
            dosym "${src_cc}" "/usr/bin/${t}-cc"
        fi
        if [[ -x "${D}${src_cxx}" ]]; then
            dosym "${src_cxx}" "/usr/bin/${t}-c++"
        fi
    done

    dodir "/usr/share/doc/llvm-mingw-${PV}"
    if [[ -f README.md ]]; then
        fcopy README.md "/usr/share/doc/llvm-mingw-${PV}/"
    fi
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV}"
    elog "Symlinks for selected triples were created under /usr/bin"
    elog "If you need different triples, rebuild with appropriate USE flags"
}

# Notes:
# - The QA failure seen earlier was caused by using ${D} inside paths passed to dodir/dosym
#   which resulted in nested ${D}/${D} directories. This version uses target-system
#   paths with dodir/dosym correctly so that the image tree ends up as ${D}/opt/...
# - LICENSE is still a placeholder; set correct licenses for releases you package.
# - If you want a build-from-source ebuild (compile LLVM + mingw-w64), request it
#   and a full build ebuild will be prepared (needs cmake/ninja/python dependencies).

