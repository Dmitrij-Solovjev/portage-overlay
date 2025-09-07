# Copyright 2025 Gentoo Authors
# SPDX-License-Identifier: GPL-2.0

EAPI=8

DESCRIPTION="llvm-mingw: build llvm-mingw toolchain (build-from-source ebuild)

This ebuild attempts to build the llvm-mingw toolchain from upstream sources
using the project's build scripts (build-all.sh / build-*.sh). It performs a
local build and installs the result under /opt/llvm-mingw-${PV} with
helper symlinks under /usr/bin for the selected target triples."

HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz"

# Upstream licensing is multi-licensed; adjust as necessary for the release.
LICENSE="MIT"
SLOT="0"
# include ~arm64 because you build on an ARM64 host
KEYWORDS="~arm64 ~amd64"
IUSE="aarch64 x86_64 i686 alltargets"

# Build-time deps (approximation). Building llvm-mingw is heavy: llvm, clang,
# ninja, cmake, python and a working native toolchain are required.
DEPEND="
    sys-devel/gcc
    sys-devel/binutils
    dev-util/cmake
    dev-util/ninja
    dev-lang/python:3
    sys-devel/make
    sys-devel/patch
    dev-vcs/git
    app-arch/xz-utils
    sys-devel/autoconf
    sys-devel/automake
    dev-util/pkgconfig
    dev-libs/zlib
    dev-libs/libxml2
"

RDEPEND=""

# upstream build script to invoke (exists in upstream repo)
_upstream_build_script="${S}/build-all.sh"

src_unpack() {
    unpack ${A}
    # Move contents from subdir "llvm-mingw-${PV}" to S
    if [[ -d "${WORKDIR}/llvm-mingw-${PV}" ]]; then
        mv "${WORKDIR}/llvm-mingw-${PV}"/* "${WORKDIR}/"
        rmdir "${WORKDIR}/llvm-mingw-${PV}" || true
    fi
}

src_prepare() {
    default
    # Ensure the upstream scripts are executable
    if [[ -f "${_upstream_build_script}" ]]; then
        chmod +x "${_upstream_build_script}" || true
    fi
}

src_configure() {
    # nothing to configure in the ebuild itself; upstream scripts handle it
    return 0
}

src_compile() {
    # Build into a temporary staging dir inside WORKDIR to avoid contaminating ${D}
    local build_root="${WORKDIR}/built"
    rm -rf "${build_root}"
    mkdir -p "${build_root}"

    # Upstream supports an invocation: ./build-all.sh <target-dir>
    if [[ -x "${_upstream_build_script}" ]]; then
        # pass some environment overrides commonly used upstream
        env \
            LLVM_VERSION="" \
            C_COMPILER_WORKS=1 \
            ${_upstream_build_script} "${build_root}" || die "upstream build-all.sh failed"
    else
        die "upstream build script ${_upstream_build_script} not found"
    fi

    # After build completes, copy staging area to a consistent place for src_install
    mv "${build_root}" "${WORKDIR}/llvm-mingw-built" || die "move built tree failed"
}

src_install() {
    # Install the built tree into ${D}/opt/llvm-mingw-${PV}
    local install_prefix="/opt/llvm-mingw-${PV}"
    dodir "${install_prefix}"

    if [[ ! -d "${WORKDIR}/llvm-mingw-built" ]]; then
        die "No built tree found — src_compile likely failed"
    fi

    cp -a "${WORKDIR}/llvm-mingw-built/." "${D}${install_prefix}/"

    # Fix perms
    if [[ -d "${D}${install_prefix}/bin" ]]; then
        find "${D}${install_prefix}/bin" -type f -exec chmod 0755 {} + || true
    fi

    # Create wrappers/symlinks for the target triples (use target-system paths)
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
            local dst="/usr/bin/${t}-${tool}"
            if [[ -x "${D}${src}" ]]; then
                dodir "$(dirname "${dst}")"
                dosym "${src}" "${dst}"
            fi
        done

        if [[ -x "${D}${install_prefix}/bin/${t}-clang" ]]; then
            dosym "${install_prefix}/bin/${t}-clang" "/usr/bin/${t}-cc"
            dosym "${install_prefix}/bin/${t}-clang++" "/usr/bin/${t}-c++"
        fi
    done

    # docs
    dodir "/usr/share/doc/llvm-mingw-${PV}"
    if [[ -f README.md ]]; then
        fcopy README.md "/usr/share/doc/llvm-mingw-${PV}/"
    fi
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV} (built-from-source)"
    elog "If some target wrappers are missing, you likely need to build a host-toolchain"
    elog "See upstream README (https://github.com/mstorsjo/llvm-mingw) for details —
  building aarch64 support may require a two-stage build (host-toolchain + target libs)."
}

# Notes to packager:
# - Upstream's build-all.sh orchestrates many sub-builds. Building on ARM hosts
#   to produce ARM-targeting compilers may require building a host-toolchain
#   (see upstream README and comments in build scripts). The ebuild above
#   automates calling the upstream script and installing the result.
# - This ebuild is heavy: expect long build times and significant disk usage.
# - Consider packaging prebuilt release artifacts (what we had before) for fast
#   installs, and providing a separate build-from-source ebuild for those who
#   need native-built toolchains.
# - Adjust DEPEND to match your tree's available packages; add python modules
#   and libraries required by the build scripts if needed.
#
# References:
# - upstream README: https://github.com/mstorsjo/llvm-mingw (build-all.sh usage)
# - notes about two-stage builds and aarch64 reliance on host-built target libs
#   in various packaging scripts (MXE, R-project packaging, etc.)

