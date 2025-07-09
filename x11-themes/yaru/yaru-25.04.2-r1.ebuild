# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=8

inherit meson git-r3 xdg-utils

DESCRIPTION="Ubuntu community theme \"yaru\"."
HOMEPAGE="https://github.com/ubuntu/yaru"
SRC_URI=""
EGIT_REPO_URI="https://github.com/ubuntu/yaru.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~arm64"
IUSE=""

DEPEND="
	dev-vcs/git
	dev-build/meson
	dev-build/ninja
"
RDEPEND="
	x11-themes/gtk-engines-murrine
	x11-themes/gnome-themes-standard
"

src_prepare() {
	default
	# Убедимся, что meson не требует сборки snap-обвязки
	sed -i '/subdir.*snap/d' meson.build || die
}

src_configure() {
	# Создаем чистую папку для сборки
	mkdir -p "${WORKDIR}/build" || die
	meson setup "${WORKDIR}/build" "${S}" || die
}

src_compile() {
	ninja -C "${WORKDIR}/build" || die
}

src_install() {
	DESTDIR="${D}" meson install -C "${WORKDIR}/build" || die
}

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}

