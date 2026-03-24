# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2023-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="pax-utils"
PKG_VERSION="1.3.10"
PKG_SHA256="2d308a923a846a0a816bf9c9fd05b5f38371e9dcfafbf976159a76f3e8e7d317"
PKG_LICENSE="GPL-2.0"
PKG_SITE="https://wiki.gentoo.org/wiki/Hardened/PaX_Utilities"
PKG_URL="https://dev.gentoo.org/~floppym/dist/pax-utils-${PKG_VERSION}.tar.xz"
PKG_DEPENDS_HOST="meson:host ninja:host"
PKG_LONGDESC="ELF utils that can check files for security relevant properties"

PKG_MESON_OPTS_HOST="-Duse_libcap=disabled \
                     -Duse_fuzzing=false"
