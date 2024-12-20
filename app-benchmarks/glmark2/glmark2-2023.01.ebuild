# Copyright 1999-2022 Gentoo Authors
# Copyright 2023 Aliaksei Urbanski
# Distributed under the terms of the GNU General Public License v2

EAPI=8


inherit meson git-r3

DESCRIPTION="glmark2 is an OpenGL 2.0 and ES 2.0 benchmark"
HOMEPAGE="https://github.com/glmark2/glmark2"
SRC_URI=""
AUTHOR="glmark2"

EGIT_REPO_URI="https://github.com/${AUTHOR}/${PN}.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 ~arm ~x86 arm64"
IUSE="+drm gles2 +opengl wayland -X"

RDEPEND="
	virtual/jpeg:0=
	media-libs/libpng:0=

	gles2? ( media-libs/mesa[gles2?] )
	drm? (
		x11-libs/libdrm
		media-libs/mesa[gbm(+)]
		virtual/libudev:=
	)
	X? ( x11-libs/libX11 )
	wayland? (
		dev-libs/wayland
		>=dev-libs/wayland-protocols-1.12
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	wayland? ( dev-util/wayland-scanner )
"

REQUIRED_USE="|| ( opengl gles2 )
			  || ( drm wayland X )"

src_configure() {
	local flavors=()

	if use X; then
		use opengl && flavors+=("x11-gl")
		use gles2 && flavors+=("x11-glesv2")
	fi

	if use drm; then
		use opengl && flavors+=("drm-gl")
		use gles2 && flavors+=("drm-glesv2")
	fi

	if use wayland; then
		use opengl && flavors+=("wayland-gl")
		use gles2 && flavors+=("wayland-glesv2")
	fi

	flavor_list() {
		local flavors="$(sort -u <<< "${1// /$'\n'}")"
		echo "${flavors//$'\n'/,}"
	}

	local emesonargs=(
		-Dflavors=$(flavor_list "${flavors[*]}")
	)
	meson_src_configure
}
