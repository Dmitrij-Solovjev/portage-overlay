# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts)"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions BSD MIT ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="alltargets aarch64 armv7 i686 x86_64"

RESTRICT="network-sandbox mirror"

S="${WORKDIR}/llvm-mingw-${PV}"

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

src_compile() {
    # Проставляем пути
    NATIVE="${WORKDIR}/native"
    PREFIX="${WORKDIR}/install"

    # Опции LLVM
    LLVM_ARGS="--full-llvm"

    # Определяем таргеты
    TARGETS=""
    [[ ${IUSE} =~ alltargets ]] && TARGETS="x86_64 i686 aarch64 armv7"
    [[ ${IUSE} =~ x86_64 ]] && TARGETS="$TARGETS x86_64"
    [[ ${IUSE} =~ i686 ]] && TARGETS="$TARGETS i686"
    [[ ${IUSE} =~ aarch64 ]] && TARGETS="$TARGETS aarch64"
    [[ ${IUSE} =~ armv7 ]] && TARGETS="$TARGETS armv7"

    # Собираем по каждому таргету
    for CROSS_ARCH in $TARGETS; do
        echo "Building for target: $CROSS_ARCH"
        # Сборка с Python (при желании можно добавить опцию)
        ./build.sh "$NATIVE" "$PREFIX" "$CROSS_ARCH" --with-python $LLVM_ARGS
    done
}

src_install() {
    # Создаём директорию для пакета
    local INSTALLDIR="${D}/usr/lib/llvm-mingw/${PV}"
    mkdir -p "$INSTALLDIR"

    # Копируем всё из рабочей директории сборки
    cp -r "${WORKDIR}/install/"* "$INSTALLDIR/"

    # Добавляем бинарники в PATH через wrapper, если нужно
    # Это необязательно, но можно создать ссылки в /usr/bin
    # Например:
    # ln -s "$INSTALLDIR/bin/x86_64-w64-mingw32-gcc" "${D}/usr/bin/x86_64-w64-mingw32-gcc"
}

pkg_postinst() {
    elog "llvm-mingw ${PV} installed in /usr/lib/llvm-mingw/${PV}"
    elog "Add /usr/lib/llvm-mingw/${PV}/bin to your PATH to use cross-compilers"
}

