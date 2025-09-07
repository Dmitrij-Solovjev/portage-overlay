EAPI=8

DESCRIPTION="LLVM/Clang/LLD based mingw-w64 toolchain (UCRT) for Windows targets"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/releases/download/${PV}/llvm-mingw-${PV}-ucrt-ubuntu-22.04-aarch64.tar.xz -> ${P}.tar.xz"

LICENSE="Apache-2.0 WITH LLVM-exception ISC"
KEYWORDS="~arm64 ~amd64"

S="${WORKDIR}/llvm-mingw-${PV}-ucrt-ubuntu-22.04-aarch64"

IUSE=""

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

DEPEND="${BDEPEND}"
SLOT="0"

src_unpack() {
    unpack ${A}
}

src_install() {
    # Ставим весь тулчейн в /opt
    dodir /opt/llvm-mingw-${PV}
    insinto /opt/llvm-mingw-${PV}
    doins -r *

    # Симлинки для бинарников кросс-компилятора
    for t in x86_64-w64-mingw32 i686-w64-mingw32 aarch64-w64-mingw32 armv7-w64-mingw32 arm64ec-w64-mingw32; do
        for tool in clang clang++ clang-cl clangd lld lldb ar as nm ranlib strip objcopy objdump gcc g++; do
            [[ -x "${S}/bin/${t}-${tool}" ]] && dosym "${S}/bin/${t}-${tool}" "/usr/bin/${t}-${tool}"
        done
    done

    # README
    [[ -f "${S}/README.md" ]] && dodoc "${S}/README.md"
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV}"
    elog "Cross-compilers installed in /usr/bin"
}

