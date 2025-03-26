# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8


inherit meson git-r3 xdg-utils

DESCRIPTION="Yaru theme from the Ubuntu Community"
HOMEPAGE="https://github.com/ubuntu/yaru"
SRC_URI=""
AUTHOR="ubuntu"

EGIT_REPO_URI="https://github.com/${AUTHOR}/${PN}.git"
EGIT_COMMIT="${PV}"

LICENSE="CC-BY-SA-4.0 GPL-3 LGPL-2.1 LGPL-3"
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
