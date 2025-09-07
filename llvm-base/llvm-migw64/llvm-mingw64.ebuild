# Copyright 2025 Gentoo Authors
# SPDX-License-Identifier: GPL-2.0

EAPI=8

DESCRIPTION="llvm-mingw: a LLVM/Clang/LLD based mingw-w64 toolchain (prebuilt installer-style ebuild template)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/releases/download/${PV}/llvm-mingw-${PV}.tar.xz"

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
    unpack ${A}
}

src_prepare() {
    default
    # upstream releases can contain absolute timestamps/ownerships; normalize
    find . -exec touch -t 198001010000 {} + || true
}

src_install() {
    # install everything into /opt so we don't fight system toolchains
    local install_prefix="${D}/opt/llvm-mingw-${PV}"
    dodir "${install_prefix}"

    # upstream release is expected to have a top-level 'llvm-mingw' directory
    # or to contain bin/ lib/ include/ etc at top-level. Copy everything.
    # (Keep it simple and robust: copy all files from the unpacked dir.)
    cp -a . "${install_prefix}/"

    # Ensure binaries are executable and permissions sane
    if [[ -d "${install_prefix}/bin" ]]; then
        find "${install_prefix}/bin" -type f -exec chmod 0755 {} + || true
    fi

    # Create /usr/bin wrappers (symlinks) for selected target triples
    # Known triple names used by llvm-mingw: x86_64-w64-mingw32 and aarch64-w64-mingw32
    local -a triples=("x86_64-w64-mingw32" "aarch64-w64-mingw32" "i686-w64-mingw32")

    # Decide which triples to expose based on USE flags
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

        # for each triple create symlinks for main tools if present
        for tool in clang clang++ clang-cl clangd lld lldb ar as nm ranlib strip objcopy objdump; do
            local src="${install_prefix}/bin/${t}-${tool}"
            local dst="${D}/usr/bin/${t}-${tool}"
            if [[ -x "${src}" ]]; then
                dodir "$(dirname "${dst}")"
                dosym "${src}" "${dst}"
            fi
        done

        # also symlink the simpler prefixed names (aarch64-w64-mingw32-clang etc)
        # and ship generic wrappers: <triple>-cc and <triple>-c++ -> clang/clang++
        if [[ -x "${install_prefix}/bin/${t}-clang" ]]; then
            dosym "${install_prefix}/bin/${t}-clang" "${D}/usr/bin/${t}-cc"
            dosym "${install_prefix}/bin/${t}-clang++" "${D}/usr/bin/${t}-c++"
        fi
    done

    # minimal metadata
    dodir "${D}/usr/share/doc/llvm-mingw-${PV}"
    fcopy README.md "${D}/usr/share/doc/llvm-mingw-${PV}/"
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV}"
    elog "Symlinks for selected triples were created under /usr/bin"
    elog "If you need different triples, rebuild with appropriate USE flags"
}

# Note to packager:
# - This is a template ebuild. Upstream releases sometimes ship prebuilt
#   archives per-host-OS (e.g. linux-host). If you want to package the
#   source + build-from-source flow, significant additions are required
#   (DEPEND on cmake, ninja, python, and invoking the repo's build scripts).
# - The LICENSE value above is a placeholder; inspect upstream for the
#   release you package and set LICENSE and SRC_URI accordingly.
# - Update KEYWORDS and REQUIRED_USE to match your tree policy.
# - If upstream changes layout, adjust src_install copy paths.
