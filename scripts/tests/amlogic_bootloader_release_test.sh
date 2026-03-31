#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

export BUILD="${TMPDIR}/build"
export RELEASE_DIR="${TMPDIR}/release"
export PROJECT="Amlogic"
export DEVICE="AMLGX"
export UBOOT_SYSTEM="phicomm-n1"

mkdir -p "${BUILD}/image/system/usr/share/bootloader"

# Provide only one DTB to reproduce CI behavior where not every glob matches.
touch "${BUILD}/image/system/usr/share/bootloader/meson-sm1-phicomm-n1.dtb"

find_file_path() {
  return 1
}

. "${ROOT_DIR}/projects/Amlogic/bootloader/release"

test -d "${RELEASE_DIR}/3rdparty/bootloader"
test -d "${RELEASE_DIR}/3rdparty/bootloader/amlogic"
test -f "${RELEASE_DIR}/3rdparty/bootloader/amlogic/meson-sm1-phicomm-n1.dtb"
