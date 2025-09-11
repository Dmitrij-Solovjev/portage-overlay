# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${PV}.tar.gz"

# Upstream contains multiple licenses for the different components.
LICENSE="Apache-2.0-with-LLVM-exceptions BSD MIT ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Upstream scripts fetch LLVM/mingw-w64 sources during build.
# Allow outgoing network in sandbox and allow upstream fetches from their servers.
RESTRICT="network-sandbox mirror"

# Source dir inside workdir after unpack
S="${WORKDIR}/llvm-mingw-${PV}"

# Build-time tools (toolchain is self-contained -> no runtime deps)
BDEPEND="
    dev-build/autoconf
    dev-build/automake
    dev-build/cmake
    dev-build/make
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
    llvm-core/clang
"

RDEPEND=""

src_prepare() {
    default
    # ensure build scripts are executable
    chmod +x "${S}/build-"*.sh || die
    chmod +x "${S}/install-wrappers.sh" "${S}/prepare-cross-toolchain"*"*.sh" 2>/dev/null || true
}

src_compile() {
    # build into a local workdir, then copy into /usr/lib/... in src_install
    export CC=${CC:-gcc}
    export CXX=${CXX:-g++}
    local out="${WORKDIR}/toolchain"
    einfo "Building llvm-mingw into ${out} (building all targets)"

    cd "${S}" || die "cd ${S} failed"

    # Upstream build-all.sh expects to fetch sources itself; do not try to
    # restrict by host here (it breaks upstream scripts). RESTRICT allows network.
    bash ./build-all.sh "${out}" || die "build-all.sh failed"

    # Basic sanity: ensure at least one triplet compiler exists
    if [[ ! -x "${out}/bin/aarch64-w64-mingw32-clang" ]] \
       && [[ ! -x "${out}/bin/x86_64-w64-mingw32-clang" ]] \
       && [[ ! -x "${out}/bin/i686-w64-mingw32-clang" ]] \
       && [[ ! -x "${out}/bin/armv7-w64-mingw32-clang" ]]; then
        die "No target compilers found under ${out}/bin"
    fi

    export LLVMMINGW_OUT="${out}"
}

src_install() {
    local dest="/usr/lib/llvm-mingw/${PV}"

    # Сохраним старые переменные (чтобы восстановить позже)
    local _save_STRIP="${STRIP-}"
    local _save_RANLIB="${RANLIB-}"
    local _save_AR="${AR-}"

    # Делать strip/ranlib no-op во время установки (они портят PE/COFF import libs)
    export STRIP="/bin/true"
    export RANLIB="/bin/true"
    # AR желательно оставить хостовым ar (или явно указать), чтобы ar не перепутал
    export AR="${AR:-/usr/bin/ar}"

    dodir "${dest}" || die
    cp -a "${LLVMMINGW_OUT}/." "${ED}${dest}" || {
        # восстановление при ошибке
        export STRIP="${_save_STRIP}"
        export RANLIB="${_save_RANLIB}"
        export AR="${_save_AR}"
        die "cp failed"
    }

    # Create a stable 'current' symlink pointing to this version
    dodir /usr/lib/llvm-mingw
    dosym "${dest}" "/usr/lib/llvm-mingw/current" || die

    # Restore STRIP/RANLIB/AR
    export STRIP="${_save_STRIP}"
    export RANLIB="${_save_RANLIB}"
    export AR="${_save_AR}"

    einstalldocs
}


multilib_src_install_all() {
    # Add PATH entry via env.d (like official llvm ebuilds do)
    newenvd - "60llvm-mingw" <<-_EOF_
PATH="${EPREFIX}/usr/lib/llvm-mingw/${PV}/bin"
ROOTPATH="${EPREFIX}/usr/lib/llvm-mingw/${PV}/bin"
_EOF_
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /usr/lib/llvm-mingw/${PV}"
    elog "Add /usr/lib/llvm-mingw/${PV}/bin to PATH or use triplet-prefixed tools in /usr/bin"
}

