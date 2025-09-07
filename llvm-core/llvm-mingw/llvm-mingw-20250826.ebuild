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
    # Определяем целевые архитектуры на основе USE-флагов
    local targets=()
    use x86_64 && targets+=(x86_64)
    use i686 && targets+=(i686)
    use aarch64 && targets+=(aarch64)
    use armv7 && targets+=(armv7)

    if [[ ${#targets[@]} -eq 0 ]]; then
        die "Не выбрана ни одна целевая архитектура. Включите хотя бы один use-флаг (aarch64, armv7, i686, x86_64)"
    fi

    # Преобразуем массив в строку с разделителем-запятой для скрипта сборки
    local arch_list=$(IFS=,; echo "${targets[*]}")

    # Вызываем скрипт сборки с указанием архитектур и префикса
    einfo "Сборка llvm-mingw для архитектур: ${arch_list}"
    export PYTHON="0"
    ./build-cross-tools.sh /usr/lib "${WORKDIR}/build" "${arch_list}" || die "Сборка не удалась"
}

src_install() {
    # Базовый путь установки для llvm-mingw
    local install_base="/usr/lib/llvm-mingw/${PV}"
    local build_dir="${WORKDIR}/build"

    if [[ ! -d "${build_dir}" ]]; then
        die "Каталог сборки ${build_dir} не существует. Убедитесь, что src_compile() выполнена успешно"
    fi

    # Создаем каталог назначения
    dodir "${install_base}"
    
    # Копируем содержимое собранного toolchain
    einfo "Установка llvm-mingw в ${ED}${install_base}"
    cp -R "${build_dir}/"* "${ED}${install_base}/" || die "Ошибка копирования файлов"

    # Создаем симлинки для удобства доступа к инструментам из PATH
    local toolchain_bin="${install_base}/bin"
    dodir "/usr/bin"
    for bin_file in "${ED}${toolchain_bin}"/*; do
        local bin_name=$(basename "${bin_file}")
        if [[ -f "${bin_file}" && -x "${bin_file}" ]]; then
            dosym "${toolchain_bin}/${bin_name}" "/usr/bin/${bin_name}"
        fi
    done

    # Устанавливаем документацию, если она есть
    if [[ -d "${S}/docs" ]]; then
        dodoc -r "${S}/docs/"*
    fi
}

pkg_postinst() {
    # Сообщение пользователю о завершении установки
    elog "LLVM/Clang/LLD-based mingw-w64 toolchain установлен в /usr/lib/llvm-mingw/${PV}/"
    elog "Основные инструменты (clang, lld, ar) доступны через симлинки в /usr/bin/"
    elog ""
    elog "Для использования в кросс-компиляции убедитесь, что целевая архитектура"
    elog "соответствует одному из включенных USE-флагов (aarch64, armv7, i686, x86_64)."
    elog ""
    elog "Пример компиляции для x86_64:"
    elog "  x86_64-w64-mingw32-clang -o program.exe program.c"
    elog ""
    elog "Путь к toolchain добавлен в переменную PATH автоматически через симлинки."
}

