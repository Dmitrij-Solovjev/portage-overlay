# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"

# Fetch a specific commit as a tarball (pinned commit e455d4c3...)
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/e455d4c3cb470216a130ca7b13f68977c2658c88.tar.gz -> llvm-mingw-master.tar.gz"


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
    # accommodate GitHub commit-named archive: rename extracted dir to expected ${PV}
    _GITDIR="${WORKDIR}/llvm-mingw-master"
    if [[ -d "${_GITDIR}" && ! -d "${WORKDIR}/llvm-mingw-${PV}" ]]; then
        mv "${_GITDIR}" "${WORKDIR}/llvm-mingw-${PV}" || die "rename source dir failed"
    fi

    default
    # ensure build scripts are executable
    chmod +x "${S}/"*.sh || die
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
    dodir "${dest}" || die
    cp -a "${LLVMMINGW_OUT}/." "${ED}${dest}" || die

    # Create a stable 'current' symlink pointing to this version
    dodir /usr/lib/llvm-mingw
    dosym "${dest}" "/usr/lib/llvm-mingw/current" || die

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

