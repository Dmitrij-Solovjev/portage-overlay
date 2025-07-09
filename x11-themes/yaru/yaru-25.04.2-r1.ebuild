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
IUSE="theme-gtk theme-icons theme-sound"

DEPEND="
	dev-vcs/git
	>=dev-util/meson-0.50
	dev-util/ninja
	virtual/pkgconfig
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
	meson setup "${BUILD_DIR}" "${S}" \
		-Dgtk_theme=$(usex theme-gtk true false) \
		-Dicon_theme=$(usex theme-icons true false) \
		-Dsound_theme=$(usex theme-sound true false)
}

src_install() {
	meson install -C "${BUILD_DIR}" --destdir="${D}" || die
}

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}

