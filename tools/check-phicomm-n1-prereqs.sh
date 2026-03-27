#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_DTB="meson-gxl-s905d-phicomm-n1.dtb"
EXPECTED_CONFIG="p212_defconfig"

actual_dtb="$("${ROOT}/scripts/uboot_helper" Amlogic AMLGX phicomm-n1 dtb)"
actual_config="$("${ROOT}/scripts/uboot_helper" Amlogic AMLGX phicomm-n1 config)"

if [[ "${actual_dtb}" != "${EXPECTED_DTB}" ]]; then
  echo "unexpected N1 DTB: ${actual_dtb}" >&2
  exit 1
fi

if [[ "${actual_config}" != "${EXPECTED_CONFIG}" ]]; then
  echo "unexpected N1 U-Boot config: ${actual_config}" >&2
  exit 1
fi

uboot_version="$(awk -F'"' '/^PKG_VERSION=/{print $2}' "${ROOT}/packages/tools/u-boot/package.mk")"
if [[ -z "${uboot_version}" ]]; then
  echo "failed to detect u-boot version" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

archive="${tmpdir}/u-boot-${uboot_version}.tar.bz2"
curl -fsSL "https://ftp.denx.de/pub/u-boot/u-boot-${uboot_version}.tar.bz2" -o "${archive}"
tar -xf "${archive}" -C "${tmpdir}"

cd "${tmpdir}/u-boot-${uboot_version}"

for patch_file in "${ROOT}"/projects/Amlogic/devices/AMLGX/patches/u-boot/*.patch; do
  patch -p1 --batch --forward < "${patch_file}" >/dev/null
done

echo "phicomm-n1 prereqs OK"
