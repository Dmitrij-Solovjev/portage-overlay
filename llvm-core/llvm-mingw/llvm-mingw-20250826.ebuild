# Copyright 2025 Gentoo Authors
# SPDX-License-Identifier: GPL-2.0

EAPI=8

DESCRIPTION="llvm-mingw: a LLVM/Clang/LLD based mingw-w64 toolchain (prebuilt installer-style ebuild template)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
# Upstream does not always publish a .tar.xz release file under Releases/distfiles.
# GitHub provides the tag archive at /archive/refs/tags/<tag>.tar.gz — use that as SRC_URI.
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz"

# NOTE: upstream bundles many components with differing licenses; this ebuild
# marks LICENSE="MIT" as a pragmatic default placeholder. Adjust to match
# upstream licensing for the specific release you package.
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"  # adjust to your arch/keyword policy
IUSE="aarch64 x86_64 i686 alltargets"

# This ebuild treats upstream release as a prebuilt toolchain archive
# and installs it under /opt/llvm-mingw-${PV}. It then creates (safe)
# symlinks in /usr/bin for the selected target triple compilers/assemblers.

DEPEND="app-arch/xz-utils"
RDEPEND=""

src_unpack() {
    # GitHub tag archives unpack into a subdirectory named "llvm-mingw-${PV}".
    unpack ${A}
    # If archive unpacked into a single subdir, cd into it so src_install copies
    # the expected layout (bin/ lib/ include/ ...)
    if [[ -d "${WORKDIR}/llvm-mingw-${PV}" ]]; then
        mv "${WORKDIR}/llvm-mingw-${PV}"/* "${WORKDIR}/"
        rmdir "${WORKDIR}/llvm-mingw-${PV}" || true
    fi
}

src_prepare() {
    default
    # Normalize timestamps/ownerships in the unpacked tree
    find . -exec touch -t 198001010000 {} + || true
}

src_install() {
    # install everything into /opt so we don't fight system toolchains
    local install_prefix="${D}/opt/llvm-mingw-${PV}"
    dodir "${install_prefix}"

    # upstream release is expected to have bin/ lib/ include/ etc at top-level.
    cp -a . "${install_prefix}/"

    # Ensure binaries are executable and permissions sane
    if [[ -d "${install_prefix}/bin" ]]; then
        find "${install_prefix}/bin" -type f -exec chmod 0755 {} + || true
    fi

    # Create /usr/bin wrappers (symlinks) for selected target triples
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
            local src="${install_prefix}/bin/${t}-${tool}"
            local dst="${D}/usr/bin/${t}-${tool}"
            if [[ -x "${src}" ]]; then
                dodir "$(dirname "${dst}")"
                dosym "${src}" "${dst}"
            fi
        done

        if [[ -x "${install_prefix}/bin/${t}-clang" ]]; then
            dosym "${install_prefix}/bin/${t}-clang" "${D}/usr/bin/${t}-cc"
            dosym "${install_prefix}/bin/${t}-clang++" "${D}/usr/bin/${t}-c++"
        fi
    done

    dodir "${D}/usr/share/doc/llvm-mingw-${PV}"
    if [[ -f README.md ]]; then
        fcopy README.md "${D}/usr/share/doc/llvm-mingw-${PV}/"
    fi
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV}"
    elog "Symlinks for selected triples were created under /usr/bin"
    elog "If you need different triples, rebuild with appropriate USE flags"
}

# Notes to packager:
# - This ebuild now fetches GitHub tag archives (refs/tags/<tag>.tar.gz).
#   If upstream publishes release artifacts (tar.xz) you prefer, you can
#   change SRC_URI to point to them or add additional SRC_URI entries.
# - LICENSE is still a placeholder: inspect the release and list the exact
#   licensing for correct packaging.
# - If you want a build-from-source ebuild (full compilation of LLVM + mingw-w64),
#   ask and I'll prepare a more complete ebuild with DEPENDs and build steps.

