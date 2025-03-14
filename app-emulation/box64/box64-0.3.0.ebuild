# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake toolchain-funcs optfeature

DESCRIPTION="Linux Userspace x86_64 Emulator with a twist"
HOMEPAGE="https://box86.org"
SRC_URI="https://github.com/ptitSeb/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~arm64 ~ppc64"
IUSE="static"

pkg_setup() {
	if [[ $(tc-endian) == big ]]; then
		eerror "box86/box64 sadly does not support big endian systems."
		die "big endian not supported!"
	fi

	if [[ ${CHOST} != *gnu* || ${CHOST} != *linux* ]]; then
		eerror "box86/64 requires a glibc and a linux system. Musl support is possible, upstream welcomes PRs!"
		die "Not a GNU+Linux system"
	fi
}

src_configure() {
	local -a mycmakeargs=(
		-DNOGIT=1
		-DARM_DYNAREC=0
		-DRV64_DYNAREC=0
	)

	(use arm || use arm64) && mycmakeargs+=( -DARM64=1 -DARM_DYNAREC=1 )
	use riscv && mycmakeargs+=( -DRV64=1 -DRV64_DYNAREC=1 )
	use ppc64 && mycmakeargs+=( -DPPC64LE=1 )
	use loong && mycmakeargs+=( -DLARCH64=1 )
	use amd64 && mycmakeargs+=( -DLD80BITS=1 -DNOALIGN=1 )
	use static && mycmakeargs+=( -DSTATICBUILD=1 )

	cmake_src_configure
}

src_install() {
    # Установка бинарного файла
    mkdir -p "${D}/usr/bin/box"
    dosbin "${S}/box64" "${D}/usr/bin/box/box64"

    # Установка дополнительных файлов
    mkdir -p "${D}/usr/lib/box64-x86-64-linux-gnu"
    cp -r "${S}/lib/." "${D}/usr/lib/box64-x86-64-linux-gnu/"

    # Установка конфигурационного файла box64rc
    mkdir -p "${D}/etc"
    cp "${S}/box64.box64rc" "${D}/etc/box64.box64rc"
    chmod 644 "${D}/etc/box64.box64rc"

    # Установка конфигурации binfmt
    mkdir -p "${D}/etc/binfmt.d"
    cp "${S}/box64.conf" "${D}/etc/binfmt.d/box64.conf"
    chmod 644 "${D}/etc/binfmt.d/box64.conf"

    # Перезагрузка binfmt (если systemd доступен)
    if command -v systemctl &>/dev/null; then
        systemctl restart systemd-binfmt
    fi

    # Очистка отладочных символов
    dostrip -x "usr/lib/x86_64-linux-gnu/*"
}


pkg_postinst() {
	optfeature "OpenGL for GLES devices" \
		"media-libs/gl4es"
}
