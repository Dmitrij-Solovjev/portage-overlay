# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Hangover runs Win64 and Win32 applications on arm64 Linux"
HOMEPAGE="https://github.com/AndreRH/hangover"
EGIT_REPO_URI="https://github.com/AndreRH/hangover.git"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~arm64"
IUSE="fex box64"

DEPEND="
    sys-devel/clang
    sys-devel/llvm
    sys-devel/llvm-mingw64
    sys-devel/make
    sys-devel/gcc
    sys-devel/binutils
    dev-util/cmake
    virtual/wine
    dev-util/ninja
    fex? ( dev-util/cmake )
    box64? ( dev-util/cmake )
"

RDEPEND="${DEPEND}"

inherit git-r3 cmake

src_unpack() {
    git-r3_src_unpack
    git submodule update --init --recursive
}

src_prepare() {
    default
}

src_configure() {
    mkdir -p wine/build || die
    cd wine/build || die

    export PATH="/usr/lib/llvm-mingw64/bin:${PATH}"

    ../configure \
        --disable-tests \
        --with-mingw=clang \
        --enable-archs=arm64ec,aarch64,i386 || die
}

src_compile() {
    cd wine/build || die
    emake -j$(nproc)

    if use fex; then
        einfo "Building arm64ecfex (FEX 64-bit thunk)..."
        mkdir -p "${S}"/fex/build_ec || die
        cd "${S}"/fex/build_ec || die
        export PATH="/usr/lib/llvm-mingw64/bin:${PATH}"

        cmake .. \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DCMAKE_TOOLCHAIN_FILE=../toolchain_mingw.cmake \
            -DENABLE_LTO=OFF \
            -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
            -DBUILD_TESTS=OFF || die

        emake -j$(nproc) arm64ecfex || die
    fi

    if use box64; then
        einfo "Building wowbox64 (Box64 32-bit thunk)..."
        mkdir -p "${S}"/box64/build_pe || die
        cd "${S}"/box64/build_pe || die
        export PATH="/usr/lib/llvm-mingw64/bin:${PATH}"

        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
            -DARM_DYNAREC=ON \
            -DWOW64=ON || die

        emake -j$(nproc) wowbox64 || die
    fi
}

src_install() {
    cd wine/build || die
    emake DESTDIR="${D}" install || die

    if use fex; then
        insinto /usr/local/lib/wine/aarch64-windows/
        doins "${S}/fex/build_ec/Bin/libarm64ecfex.dll" || die
    fi

    if use box64; then
        insinto /usr/local/lib/wine/aarch64-windows/
        doins "${S}/box64/build_pe/wowbox64-prefix/src/wowbox64-build/wowbox64.dll" || die
    fi
}

