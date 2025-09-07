EAPI=8
DESCRIPTION="LLVM/Clang/LLD based mingw-w64 toolchain (UCRT) for Windows targets"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/releases/download/${PV}/llvm-mingw-${PV}-ucrt-aarch64.zip"
LICENSE="Apache-2.0 WITH LLVM-exception ISC"
KEYWORDS="~arm64 ~amd64"

IUSE=""
# Зависимости для распаковки и установки (в том числе unzip для распаковки .zip:contentReference[oaicite:3]{index=3})
BDEPEND="
    dev-build/autoconf
    dev-build/automake
    dev-build/cmake
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
"

DEPEND="${BDEPEND}"  # нет дополнительных зависимостей во время сборки

SLOT="0"

src_unpack() {
    unpack ${A}
}
src_prepare(){
    S="${WORKDIR}/${P}-ucrt-aarch64"
}


src_install() {
    # Переходим в директорию с распакованным содержимым
    cd "${S}" || die "Failed to change to source directory"

    # Копируем весь распакованный тулчейн в /opt/llvm-mingw-${PV}
    dodir /opt/llvm-mingw-${PV}
    insinto /opt/llvm-mingw-${PV}
    doins -r *

    # Создаём симлинки на основные исполняемые файлы для каждой целевой триплеты
    for triplet in x86_64-w64-mingw32 i686-w64-mingw32 aarch64-w64-mingw32 armv7-w64-mingw32; do
        dosym -r /opt/llvm-mingw-${PV}/bin/clang       /usr/bin/${triplet}-clang
        dosym -r /opt/llvm-mingw-${PV}/bin/clang++     /usr/bin/${triplet}-clang++
        dosym -r /opt/llvm-mingw-${PV}/bin/ld          /usr/bin/${triplet}-ld
        dosym -r /opt/llvm-mingw-${PV}/bin/llvm-ar     /usr/bin/${triplet}-ar
        dosym -r /opt/llvm-mingw-${PV}/bin/llvm-as     /usr/bin/${triplet}-as
        dosym -r /opt/llvm-mingw-${PV}/bin/llvm-ranlib /usr/bin/${triplet}-ranlib
    done

    # Устанавливаем README.md в /usr/share/doc/llvm-mingw-${PV} (если он есть)
    if [[ -f README.md ]]; then
        dodoc README.md
    fi
}

