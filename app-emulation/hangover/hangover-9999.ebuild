# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 cmake

DESCRIPTION="Hangover: run Win64 and Win32 applications on aarch64 Linux"
HOMEPAGE="https://github.com/AndreRH/hangover"
EGIT_REPO_URI="https://github.com/AndreRH/hangover.git"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~arm64"
IUSE="+fex box64"
REQUIRED_USE="^^ ( fex box64 )"

# build-time deps (минимальные для сборки wine + возможных сабмодулей)
DEPEND="
    llvm-core/llvm-mingw
    dev-build/cmake
    dev-build/ninja
    dev-build/make
    llvm-core/llvm
    llvm-core/clang
    sys-devel/gcc
    sys-devel/binutils
    app-emulation/FEX[mingw_dlls]
    box64? ( app-emulation/box64[wowbox64] )
"

# runtime deps: если включён USE, зависим от внешнего пакета (он должен обеспечить DLL)
RDEPEND="
    app-emulation/FEX[mingw_dlls]
    box64? ( app-emulation/box64[wowbox64] )
"

LLVM_MINGW_PATH="/usr/lib/llvm-mingw64/bin"

src_unpack() {
    git-r3_src_unpack
    pushd "${S}" >/dev/null || die
    git submodule update --init --recursive || die
    popd >/dev/null || die
}

src_prepare() {
    default
    export PATH="${LLVM_MINGW_PATH}:${PATH}"
}

src_configure() {
    mkdir -p "${S}/wine/build" || die
    cd "${S}/wine/build" || die
    ../configure \
        --disable-tests \
        --with-mingw=clang \
        --enable-archs=arm64ec,aarch64,i386 || die
}

src_compile() {
    cd "${S}/wine/build" || die
    emake -j$(nproc)
}

src_install() {
    cd "${S}/wine/build" || die
    emake DESTDIR="${D}" install || die

    insinto "${EPREFIX}/usr/local/lib/wine/aarch64-windows/"
    doins "${EPREFIX}/usr/lib/fex-dll-libs/libarm64ecfex.dll" || die

    if use fex; then
        doins "${EPREFIX}/usr/lib/fex-dll-libs/libwow64fex.dll" || die
    fi

    if use box64; then
        doins "${EPREFIX}/usr/lib/box64-x86_64-linux-gnu/wowbox64.dll" || die
    fi
}
