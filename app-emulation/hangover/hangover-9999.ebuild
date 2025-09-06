# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 cmake

DESCRIPTION="Hangover: run Win64 and Win32 applications on aarch64 Linux"
HOMEPAGE="https://github.com/AndreRH/hangover"
EGIT_REPO_URI="https://github.com/AndreRH/hangover.git"

# явно перечисляем субмодули, Portage их вытянет
EGIT_SUBMODULES=(
    "wine"
    "fex"
    "box64"
)

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~arm64"
# USE-флаги означают "использовать системный/внешний пакет"
IUSE="fex box64"

# build-time deps (минимальные для сборки wine + возможных сабмодулей)
DEPEND="
    dev-util/llvm-mingw64
    dev-build/cmake
    dev-build/ninja
    dev-build/make
    llvm-core/llvm
    llvm-core/clang
    sys-devel/gcc
    sys-devel/binutils
    # если хотим использовать систему fex/box64 — требуем соответствующие пакеты
    fex? ( app-emulation/fex )
    box64? ( app-emulation/box64[wowbox64] )
"

# runtime deps: если включён USE, зависим от внешнего пакета (он должен обеспечить DLL)
RDEPEND="
    fex? ( app-emulation/fex )
    box64? ( app-emulation/box64[wowbox64] )
"

src_prepare() {
    default || die
}

src_configure() {
    # Wine build directory (мы используем wine из сабмодуля hangover/wine)
    mkdir -p "${S}/wine/build" || die
    cd "${S}/wine/build" || die

    # llvm-mingw должен быть в PATH для cross-пользования
    export PATH="/usr/lib/llvm-mingw/bin:${PATH}"

    ../configure \
        --disable-tests \
        --with-mingw=clang \
        --enable-archs=arm64ec,aarch64,i386 || die
}

src_compile() {
    # build wine from vendored wine
    cd "${S}/wine/build" || die
    emake ${MAKEOPTS} || die

    # FEX: если пользователь предпочёл системный пакет — пропускаем локальную сборку
    if use fex; then
        einfo "Using system fex (app-emulation/fex); skipping vendored fex build."
    else
        einfo "Building arm64ecfex (vendored FEX 64-bit thunk)..."
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
        cd "${S}" || die
    fi

    # Box64: если пользователь предпочёл системный пакет — пропускаем локальную сборку
    if use box64; then
        einfo "Using system box64 (app-emulation/box64); skipping vendored box64 build."
    else
        einfo "Building wowbox64 (vendored Box64 32-bit thunk)..."
        mkdir -p "${S}/box64/build_pe" || die
        cd "${S}/box64/build_pe" || die

        # попробуем сначала системный кросс-компилятор gentoo-стиля, иначе fallback на clang
        if command -v aarch64-unknown-linux-gnu-gcc >/dev/null 2>&1 ; then
            CC=aarch64-unknown-linux-gnu-gcc
            CXX=aarch64-unknown-linux-gnu-g++
        else
            # если нет кросс-гуцка, используем clang (из llvm-mingw в PATH)
            CC=clang
            CXX=clang++
        fi

        export PATH="/usr/lib/llvm-mingw/bin:${PATH}"

        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="${CC}" \
            -DCMAKE_CXX_COMPILER="${CXX}" \
            -DARM_DYNAREC=ON \
            -DWOW64=ON || die

        emake ${MAKEOPTS} wowbox64 || die
        cd "${S}" || die
    fi
}

src_install() {
    # устанавливаем wine, как делает vendored wine
    cd "${S}/wine/build" || die
    emake DESTDIR="${D}" install || die

    # Если мы собрали внутренний fex, установим его dll в нужную папку
    if ! use fex; then
        if [[ -f "${S}/fex/build_ec/Bin/libarm64ecfex.dll" ]]; then
            insinto /usr/lib/wine/aarch64-windows/
            doins "${S}/fex/build_ec/Bin/libarm64ecfex.dll" || die
        else
            einfo "Vendored FEX build: expected libarm64ecfex.dll not found; skipping."
        fi
    else
        einfo "System fex is used; assuming it provides necessary DLLs."
    fi

    # Если мы собрали внутренний box64, установим его dll
    if ! use box64; then
        if [[ -f "${S}/box64/build_pe/wowbox64-prefix/src/wowbox64-build/wowbox64.dll" ]]; then
            insinto /usr/lib/wine/aarch64-windows/
            doins "${S}/box64/build_pe/wowbox64-prefix/src/wowbox64-build/wowbox64.dll" || die
        else
            einfo "Vendored Box64 build: expected wowbox64.dll not found; skipping."
        fi
    else
        einfo "System box64 is used; assuming it provides necessary DLLs."
    fi
}

