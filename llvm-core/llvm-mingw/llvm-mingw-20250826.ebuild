EAPI=8
DESCRIPTION="LLVM/Clang/LLD based mingw-w64 toolchain (UCRT) for Windows targets"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.zip -> ${P}.zip"
LICENSE="Apache-2.0 WITH LLVM-exception ISC"
KEYWORDS="~arm64 ~amd64"

S="${WORKDIR}/llvm-mingw-${PV}"


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

src_install() {
    # Переходим в директорию с распакованным содержимым
    cd "${S}" || die "Failed to change to source directory"

    # Копируем весь распакованный тулчейн в /opt/llvm-mingw-${PV}
    dodir /opt/llvm-mingw-${PV}
    insinto /opt/llvm-mingw-${PV}
    doins -r *

    # Создаём симлинки на основные исполняемые файлы для каждой целевой триплеты
    for t in x86_64-w64-mingw32 i686-w64-mingw32 aarch64-w64-mingw32 armv7-w64-mingw32 arm64ec-w64-mingw32; do
        for tool in clang clang++ clang-cl clangd lld lldb ar as nm ranlib strip objcopy objdump gcc g++; do
            [[ -x "${S}/bin/${t}-${tool}.exe" ]] && dosym "${S}/bin/${t}-${tool}.exe" "/usr/bin/${t}-${tool}"
        done
    done


    # Устанавливаем README.md в /usr/share/doc/llvm-mingw-${PV} (если он есть)
    if [[ -f README.md ]]; then
        dodoc README.md
    fi
}

