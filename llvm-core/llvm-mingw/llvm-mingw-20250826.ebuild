# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain"
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions BSD MIT ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="alltargets aarch64 armv7 i686 x86_64"

RESTRICT="network-sandbox mirror"

S="${WORKDIR}/llvm-mingw-${PV}"

BDEPEND="
    # ... существующие зависимости ...
"

src_compile() {
    export CC=${CC:-gcc}
    export CXX=${CXX:-g++}
    local out="${WORKDIR}/toolchain"
    
    # Определяем целевые архитектуры для сборки LLVM
    local llvm_targets=()
    
    # Всегда включаем нативную архитектуру (aarch64)
    llvm_targets+=(AArch64)
    
    # Добавляем цели на основе USE-флагов
    use aarch64 && llvm_targets+=(AArch64)
    use armv7 && llvm_targets+=(ARM)
    use i686 && llvm_targets+=(X86)
    use x86_64 && llvm_targets+=(X86)
    
    # Убираем дубликаты
    local unique_targets=$(printf "%s\n" "${llvm_targets[@]}" | sort -u | tr '\n' ';' | sed 's/;$//')
    
    # Экспортируем для использования в скриптах сборки
    export LLVM_TARGETS_TO_BUILD="${unique_targets}"
    
    einfo "Building llvm-mingw for targets: ${unique_targets}"
    bash ./build-all.sh "${out}" || die "build-all.sh failed"
    
    export LLVMMINGW_OUT="${out}"
}

# Остальная часть ebuild без изменений
