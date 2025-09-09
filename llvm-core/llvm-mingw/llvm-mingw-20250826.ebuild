# Copyright 2025 Your Name
EAPI=8

DESCRIPTION="llvm-mingw (LLVM + mingw-w64 cross toolchain)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI=""

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="aarch64 x86_64 arm"

# Используем предоставленные расположения (зависимости) + clang (обязателен для build-all.sh)
DEPEND="
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
    dev-lang/clang
"

RDEPEND="${DEPENd}" # оставляем RDEPEND равным DEPEND (при необходимости раздели)

src_unpack() {
    git clone --depth 1 https://github.com/mstorsjo/llvm-mingw.git "${WORKDIR}/llvm-mingw" || die "git clone failed"
    S="${WORKDIR}/llvm-mingw"
}

_src_select_target() {
    if use aarch64; then
        TARGET_TRIPLE="aarch64-w64-mingw32"
    elif use x86_64; then
        TARGET_TRIPLE="x86_64-w64-mingw32"
    elif use arm; then
        TARGET_TRIPLE="armv7-w64-mingw32"
    else
        ewarn "No target USE flag set — defaulting to aarch64"
        TARGET_TRIPLE="aarch64-w64-mingw32"
    fi

    # Проверка: не более одного флага
    enabled=0
    for f in aarch64 x86_64 arm; do
        if use $f; then
            enabled=$((enabled+1))
        fi
    done
    if [ $enabled -gt 1 ]; then
        die "Only one of aarch64|x86_64|arm USE flags may be set"
    fi
}

src_configure() {
    _src_select_target
    PREFIX_DIR="${D}/usr/lib/llvm-mingw/${PV}"
    einfo "Configuring build: target=${TARGET_TRIPLE}, install prefix=${PREFIX_DIR}"
}

src_compile() {
    _src_select_target
    PREFIX_DIR="${D}/usr/lib/llvm-mingw/${PV}"
    mkdir -p "${PREFIX_DIR}" || die "mkdir failed"
    cd "${S}" || die "cd ${S} failed"

    einfo "Running build-all.sh --host=${TARGET_TRIPLE} ${PREFIX_DIR}"
    # Запускаем сборку; если нужны дополнительные опции (cfguard, ucrt и т.д.) — можно расширить здесь.
    ./build-all.sh "${PREFIX_DIR}" --host="${TARGET_TRIPLE}" || die "build-all.sh failed"
}

src_install() {
    # build-all.sh устанавливает в ${D}/usr/lib/llvm-mingw/${PV}
    BIN_DIR="/usr/lib/llvm-mingw/${PV}/bin"

    if [ -d "${D}${BIN_DIR}" ]; then
        einfo "Creating wrappers in ${D}/usr/bin for tools from ${BIN_DIR}"
        TOOLS_LIST="${TARGET_TRIPLE}-clang ${TARGET_TRIPLE}-clang++ ${TARGET_TRIPLE}-ld.lld ${TARGET_TRIPLE}-ar ${TARGET_TRIPLE}-ranlib ${TARGET_TRIPLE}-windres"

        dodir /usr/bin
        for t in ${TOOLS_LIST}; do
            src="${BIN_DIR}/${t}"
            dest="${D}/usr/bin/${t}"
            if [ -e "${D}${src}" ]; then
                # создаём симлинк в установленной системе, указывающий на /usr/lib/llvm-mingw/${PV}/bin/...
                ln -s "/usr/lib/llvm-mingw/${PV}/bin/${t}" "${dest}" || die "failed to create symlink ${dest}"
            else
                einfo "Tool ${t} not built; skipping symlink"
            fi
        done
    else
        ewarn "${BIN_DIR} not found — no wrappers created"
    fi
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed to /usr/lib/llvm-mingw/${PV}"
    elog "Add /usr/lib/llvm-mingw/${PV}/bin to PATH or use triplet-prefixed tools in /usr/bin"
}

