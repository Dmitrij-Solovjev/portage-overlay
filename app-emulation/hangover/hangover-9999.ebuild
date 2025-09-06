# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 cmake

DESCRIPTION="Hangover: run Win64 and Win32 applications on aarch64 Linux"
HOMEPAGE="https://github.com/AndreRH/hangover"
EGIT_REPO_URI="https://github.com/AndreRH/hangover.git"

# submodules are handled via EGIT_SUBMODULES
EGIT_SUBMODULES=(
    "wine"
    "fex"
    "box64"
)

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~arm64"
IUSE="fex box64"

# build-time deps
DEPEND="
    dev-util/llvm-mingw64
    dev-build/cmake
    dev-build/ninja
    dev-build/make
    sys-devel/gcc
    sys-devel/binutils
    llvm-core/clang
    llvm-core/llvm
"

# runtime deps (do not pull virtual/wine!)
RDEPEND=""

src_prepare() {
    default || die
}

src_configure() {
    # Wine build directory
    mkdir -p "${S}/wine/build" || die
    cd "${S}/wine/build" || die

    export PATH="/usr/lib/llvm-mingw/bin:${PATH}"

    ../configure \
        --disable-tests \
        --with-mingw=clang \
        --enable-archs=arm64ec,aarch64,i386 || die
}

src_compile() {
    # build wine
    cd "${S}/wine/build" || die
    emake ${MAKEOPTS} || die

    if use fex; then
        einfo "Building arm64ecfex (FEX 64-bit thunk)..."
        mkdir -p "${S}/fex/build_ec" || die
        cd "${S}/fex/build_ec" || die
        export PATH="/usr/lib/llvm-mingw/bin:${PATH}"

        cmake .. \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DCMAKE_TOOLCHAIN_FILE=../toolchain_mingw.cmake \
            -DENABLE_LTO=OFF \
            -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
            -DBUILD_TESTS=OFF || die

        emake ${MAKEOPTS} arm64ecfex || die
    fi

    if use box64; then
        einfo "Building wowbox64 (Box64 32-bit thunk)..."
        mkdir -p "${S}/box64/build_pe" || die
        cd "${S}/box64/build_pe" || die
        export PATH="/usr/lib/llvm-mingw/bin:${PATH}"

        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
            -DARM_DYNAREC=ON \
            -DWOW64=ON || die

        emake ${MAKEOPTS} wowbox64 || die
    fi
}

src_install() {
    cd "${S}/wine/build" || die
    emake DESTDIR="${D}" install || die

    if use fex; then
        insinto /usr/lib/wine/aarch64-windows/
        doins "${S}/fex/build_ec/Bin/libarm64ecfex.dll" || die
    fi

    if use box64; then
        insinto /usr/lib/wine/aarch64-windows/
        doins "${S}/box64/build_pe/wowbox64-prefix/src/wowbox64-build/wowbox64.dll" || die
    fi
}

