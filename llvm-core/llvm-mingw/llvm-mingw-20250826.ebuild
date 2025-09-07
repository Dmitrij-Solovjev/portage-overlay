# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

DESCRIPTION="LLVM/Clang/LLD + mingw-w64 for Windows cross-compilation"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="aarch64 x86_64 i686"

BDEPEND="
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
"

S="${WORKDIR}/${P}"

src_compile() {
	# llvm-mingw использует build-all.sh для сборки
	# по умолчанию собирает все архитектуры, поэтому подрежем через USE
	local targets=()

	use aarch64 && targets+=(aarch64)
	use x86_64 && targets+=(x86_64)
	use i686 && targets+=(i686)

	if [[ ${#targets[@]} -eq 0 ]]; then
		die "No targets selected, enable at least one of: aarch64, x86_64, i686"
	fi

	# Сборка в отдельной папке
	mkdir build || die
	cd build || die

	# Запуск сборочного скрипта
	../build-all.sh "${targets[@]}" || die "build failed"
}

src_install() {
	# Ставим всё содержимое в /usr/lib/llvm-mingw/${PV}
	insinto /usr/lib/${PN}/${PV}
	doins -r build/*

	# Симлинки на компиляторы в /usr/bin
	use aarch64 && dosym ../lib/${PN}/${PV}/bin/aarch64-w64-mingw32-clang /usr/bin/aarch64-w64-mingw32-clang
	use x86_64 && dosym ../lib/${PN}/${PV}/bin/x86_64-w64-mingw32-clang /usr/bin/x86_64-w64-mingw32-clang
	use i686   && dosym ../lib/${PN}/${PV}/bin/i686-w64-mingw32-clang     /usr/bin/i686-w64-mingw32-clang

	# Документация
	dodoc README.md
}

