# Copyright 2025 Gentoo Authors
# SPDX-License-Identifier: GPL-2.0

EAPI=8

DESCRIPTION="LLVM/Clang/LLD-based mingw-w64 toolchain (built from source via upstream build scripts). Installs into /usr/lib/llvm-mingw/${PV} with user-visible symlinks in /usr/bin."
HOMEPAGE="https://github.com/mstorsjo/llvm-mingw"
SRC_URI="https://github.com/mstorsjo/llvm-mingw/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="aarch64 x86_64 i686 alltargets"

# Build-time deps (as you provided / corrected)
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

RDEPEND=""

# Workdir points to unpacked top-level of upstream tag
S="${WORKDIR}/llvm-mingw-${PV}"

src_unpack() {
	unpack ${A}
	# GitHub tag archives usually unpack into a single directory 'llvm-mingw-${PV}'
	# S already points to that directory.
}

src_prepare() {
	default
	# Ensure upstream scripts are executable
	if [[ -d "${S}" ]]; then
		chmod +x "${S}"/build-*.sh || true
		chmod +x "${S}"/prepare-cross-toolchain*.sh || true
		chmod +x "${S}"/install-wrappers.sh || true
	fi
}

src_compile() {
	# Build in upstream repo root: upstream scripts expect to be run from S
	if [[ ! -f "${S}/build-all.sh" ]]; then
		die "upstream build-all.sh not found in ${S}"
	fi

	local outdir="${WORKDIR}/toolchain"
	rm -rf "${outdir}"
	mkdir -p "${outdir}"

	einfo "Running upstream build-all.sh from ${S}, output -> ${outdir}"
	pushd "${S}" >/dev/null || die

	# upstream build-all.sh historically accepts a single argument: the output dir.
	# run it from repo root so relative helper scripts are found.
	./build-all.sh "${outdir}" || {
		local rc=$?
		popd >/dev/null || true
		die "upstream build-all.sh failed with exit ${rc}. Check ${WORKDIR}/toolchain and build logs"
	}

	popd >/dev/null || true

	# move/copy built tree to a stable location for src_install
	if [[ -d "${outdir}" ]]; then
		mv "${outdir}" "${WORKDIR}/llvm-mingw-built" || die "move built tree failed"
	else
		die "expected built tree at ${outdir} not found"
	fi
}

src_install() {
	# install into /usr/lib/llvm-mingw/${PV} (FHS-friendly prefix)
	local dest="/usr/lib/llvm-mingw/${PV}"
	dodir "${dest}"

	if [[ ! -d "${WORKDIR}/llvm-mingw-built" ]]; then
		die "No built tree found — src_compile likely failed"
	fi

	# copy built tree into image
	cp -a "${WORKDIR}/llvm-mingw-built/." "${D}${dest}/" || die

	# ensure shipped binaries executable
	if [[ -d "${D}${dest}/bin" ]]; then
		find "${D}${dest}/bin" -type f -exec chmod 0755 {} + || true
	fi

	# create symlinks for selected triples in /usr/bin -> point to /usr/lib/llvm-mingw/${PV}/bin/
	local -a triples=("aarch64-w64-mingw32" "x86_64-w64-mingw32" "i686-w64-mingw32" "armv7-w64-mingw32")

	local expose_all=0
	if use alltargets; then
		expose_all=1
	fi

	for t in "${triples[@]}"; do
		case "${t}" in
			aarch64-w64-mingw32)
				if ! use aarch64 && [[ ${expose_all} -eq 0 ]]; then
					continue
				fi
				;;
			x86_64-w64-mingw32)
				if ! use x86_64 && [[ ${expose_all} -eq 0 ]]; then
					continue
				fi
				;;
			i686-w64-mingw32)
				if ! use i686 && [[ ${expose_all} -eq 0 ]]; then
					continue
				fi
				;;
			armv7-w64-mingw32)
				if ! use armv7 && [[ ${expose_all} -eq 0 ]]; then
					continue
				fi
				;;
		esac

		# link common tools
		for tool in clang clang++ ar ranlib nm objdump windres dlltool lld lld-link as strip addr2line; do
			local src="${dest}/bin/${t}-${tool}"
			local dst="/usr/bin/${t}-${tool}"
			if [[ -x "${D}${src}" ]]; then
				dodir "$(dirname "${dst}")"
				dosym "${src}" "${dst}"
			fi
		done

		# convenient cc/c++ names
		if [[ -x "${D}${dest}/bin/${t}-clang" ]]; then
			dosym "${dest}/bin/${t}-clang" "/usr/bin/${t}-cc"
		fi
		if [[ -x "${D}${dest}/bin/${t}-clang++" ]]; then
			dosym "${dest}/bin/${t}-clang++" "/usr/bin/${t}-c++"
		fi
	done

	# docs
	dodir "/usr/share/doc/llvm-mingw-${PV}"
	if [[ -f "${S}/README.md" ]]; then
		fcopy "${S}/README.md" "/usr/share/doc/llvm-mingw-${PV}/"
	fi
}

pkg_postinst() {
	elog "llvm-mingw ${PV} installed under /usr/lib/llvm-mingw/${PV}"
	elog "Binaries for selected triples are symlinked into /usr/bin"
}

# NOTES:
# - This ebuild runs build-all.sh from ${S} (repo root) to avoid \"No such file build-llvm.sh\" errors.
# - If build-all.sh still doesn't produce certain target compilers (e.g. aarch64),
#   upstream may require a two-stage host-toolchain build; ask and I'll add a two-stage flow.
# - Adjust BDEPEND if your tree uses different categories.

