# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

#inherit meson git-r3 gnome2-util xdg-utils
inherit meson git-r3 xdg-utils

DESCRIPTION="Ubuntu community theme \"yaru\"."
HOMEPAGE="https://github.com/ubuntu/yaru"
SRC_URI=""
AUTHOR="ubuntu"

EGIT_REPO_URI="https://github.com/${AUTHOR}/${PN}.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86 arm64"
IUSE=""

DEPEND="
	dev-vcs/git
"

BDEPEND="
   dev-lang/sassc
"

RDEPEND="
   x11-themes/gtk-engines-murrine
   x11-themes/gnome-themes-standard
"

pkg_preinst() {
   gnome2_icon_savelist
}

pkg_postinst() {
   xdg_icon_cache_update
}

pkg_postrm() {
   xdg_icon_cache_update
}
