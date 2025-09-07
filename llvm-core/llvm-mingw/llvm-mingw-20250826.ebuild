# Copyright 2025 Gentoo Authors
# SPDX-License-Identifier: GPL-2.0

EAPI=8

DESCRIPTION="llvm-mingw: prebuilt llvm-mingw toolchain with full target support"

HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/releases/download/${PV}/llvm-mingw-${PV}-ucrt-aarch64.zip -> llvm-mingw-${PV}-ucrt-aarch64.zip"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~arm64 ~amd64"

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

RDEPEND=""

src_unpack() {
    unpack ${A}
    local zip_file="${DISTDIR}/llvm-mingw-${PV}-ucrt-aarch64.zip"
    [[ -f "$zip_file" ]] || die "zip file not found in DISTDIR"
    unzip -q "$zip_file" -d "${WORKDIR}/llvm-mingw-extracted" || die "unzip failed"
    mv "${WORKDIR}/llvm-mingw-extracted"/* "${WORKDIR}/"
    rm -rf "${WORKDIR}/llvm-mingw-extracted"
}

src_prepare() {
    default
}

src_configure() {
    return 0
}

src_compile() {
    return 0
}

src_install() {
    local install_prefix="/opt/llvm-mingw-${PV}"
    dodir "${D}${install_prefix}"
    cp -a . "${D}${install_prefix}/"

    [[ -d "${D}${install_prefix}/bin" ]] && find "${D}${install_prefix}/bin" -type f -exec chmod 0755 {} + || true

    local -a triples=("x86_64-w64-mingw32" "aarch64-w64-mingw32" "i686-w64-mingw32")
    for t in "${triples[@]}"; do
        for tool in clang clang++ clang-cl clangd lld lldb ar as nm ranlib strip objcopy objdump; do
            local src="${install_prefix}/bin/${t}-${tool}"
            local dst="/usr/bin/${t}-${tool}"
            [[ -x "${D}${src}" ]] && { dodir "$(dirname "${dst}")"; dosym "${src}" "${dst}"; }
        done

        [[ -x "${D}${install_prefix}/bin/${t}-clang" ]] && {
            dosym "${install_prefix}/bin/${t}-clang" "/usr/bin/${t}-cc"
            dosym "${install_prefix}/bin/${t}-clang++" "/usr/bin/${t}-c++"
        }
    done

    dodir "${D}/usr/share/doc/llvm-mingw-${PV}"
    [[ -f README.md ]] && fcopy README.md "${D}/usr/share/doc/llvm-mingw-${PV}/"
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /opt/llvm-mingw-${PV}"
    elog "All target wrappers are installed in /usr/bin"
    elog "No USE flags needed; all supported triples are included"
}

