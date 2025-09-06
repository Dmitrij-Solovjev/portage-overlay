# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 cmake

DESCRIPTION="Hangover: run Win64 and Win32 applications on aarch64 Linux"
HOMEPAGE="https://github.com/AndreRH/hangover"
EGIT_REPO_URI="https://github.com/AndreRH/hangover.git"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~arm64"
IUSE="fex box64"

# build-time deps (минимальные для сборки wine + возможных сабмодулей)
DEPEND="
    dev-util/llvm-mingw64
    dev-build/cmake
    dev-build/ninja
    dev-build/make
    llvm-core/llvm
    llvm-core/clang
    sys-devel/gcc
    sys-devel/binutils
    fex? ( app-emulation/fex )
    box64? ( app-emulation/box64[wowbox64] )
"

# runtime deps: если включён USE, зависим от внешнего пакета (он должен обеспечить DLL)
RDEPEND="
    fex? ( app-emulation/fex )
    box64? ( app-emulation/box64[wowbox64] )
"

# Не должно быть никаких символов, не относящихся к правильному синтаксису зависимости в DEPEND или RDEPEND

