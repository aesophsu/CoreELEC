# Phicomm N1 Minimal Port Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a bootable `coreelec-22` image for Phicomm N1 on the official `Amlogic/AMLGX` stack with the smallest possible board-specific change set.

**Architecture:** Keep `phicomm-n1` as a board identity inside the existing `AMLGX` image flow, but continue using the N1 vendor boot chain rather than introducing a custom U-Boot flash path. Restrict code changes to N1 build selection, N1 DTS, N1 firmware data, and removal of unrelated obsolete AMLGX U-Boot patches that block host-tool builds on modern upstream U-Boot.

**Tech Stack:** CoreELEC build system, `projects/Amlogic`, `AMLGX`, Linux DTS patching, Amlogic boot scripts, GitHub Actions.

---

### Task 1: Keep a Single Active N1 Development Branch

**Files:**
- Modify: `.github/workflows/build-phicomm-n1.yml`
- Reference: `docs/plans/2026-03-23-phicomm-n1-coreelec22-design.md`
- Reference: `docs/plans/2026-03-23-phicomm-n1-coreelec22-port.md`

**Step 1: Verify branch strategy**

Run:

```bash
git branch -vv
```

Expected: `coreelec-22` is the only branch that should continue receiving N1 changes.

**Step 2: Verify workflow trigger coverage**

Run:

```bash
sed -n '1,80p' .github/workflows/build-phicomm-n1.yml
```

Expected: the workflow triggers on `coreelec-22` pushes.

**Step 3: Minimal implementation**

- Keep `coreelec-22` as the active N1 branch.
- Keep `phicomm-n1-coreelec22-port` as historical reference only.
- Do not add new N1 work to the old branch.

**Step 4: Verify**

Run:

```bash
git branch -vv
```

Expected: no active development depends on the old branch.

**Step 5: Commit**

```bash
git add .github/workflows/build-phicomm-n1.yml
git commit -m "ci: run phicomm n1 workflow from coreelec-22"
```

### Task 2: Freeze the Minimal N1 Build Identity

**Files:**
- Modify: `scripts/uboot_helper`
- Modify: `projects/Amlogic/bootloader/install`
- Modify: `projects/Amlogic/bootloader/mkimage`

**Step 1: Write the failing test**

Run:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 config
```

Expected: if either lookup fails, the N1 target is not wired correctly.

**Step 2: Verify current behavior**

Run:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 config
```

Expected:

```text
meson-gxl-s905d-phicomm-n1.dtb
p212_defconfig
```

**Step 3: Minimal implementation**

- Keep `phicomm-n1` mapped to `meson-gxl-s905d-phicomm-n1.dtb`.
- Keep `phicomm-n1` using the vendor-bootloader path in `bootloader/install`.
- Keep `phicomm-n1` generating a board-fixed DTB selection in `bootloader/mkimage`.

**Step 4: Verify**

Run:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 config
```

Expected: same correct outputs as above.

**Step 5: Commit**

```bash
git add scripts/uboot_helper projects/Amlogic/bootloader/install projects/Amlogic/bootloader/mkimage
git commit -m "feat(amlogic): keep minimal phicomm n1 boot flow"
```

### Task 3: Remove Non-N1 AMLGX U-Boot Patch Debt That Breaks Modern Builds

**Files:**
- Modify: `projects/Amlogic/devices/AMLGX/patches/u-boot/*`

**Step 1: Write the failing test**

Run:

```bash
tmpdir=$(mktemp -d)
cd "$tmpdir"
curl -fsSL https://ftp.denx.de/pub/u-boot/u-boot-2026.01.tar.bz2 -o u-boot.tar.bz2
tar -xf u-boot.tar.bz2
cd u-boot-2026.01
for p in /Users/sue/code/CoreELEC-official/projects/Amlogic/devices/AMLGX/patches/u-boot/*.patch; do
  patch -p1 --batch --forward < "$p" >/tmp/uboot-patchcheck.log 2>&1 || { cat /tmp/uboot-patchcheck.log; exit 1; }
done
```

Expected: old AMLGX board patches fail on upstreamed files.

**Step 2: Verify it fails**

Run the command above before cleanup.

Expected: failure on already-upstreamed WeTek, Radxa, Beelink, or Banana Pi patches.

**Step 3: Minimal implementation**

- Delete only AMLGX U-Boot patches that are unrelated to N1 and already conflict with upstream `u-boot-2026.01`.
- Do not add replacement code for those boards.
- Keep only patches still needed by the current official tree and not blocking the N1 build path.

**Step 4: Verify**

Re-run:

```bash
tmpdir=$(mktemp -d)
cd "$tmpdir"
curl -fsSL https://ftp.denx.de/pub/u-boot/u-boot-2026.01.tar.bz2 -o u-boot.tar.bz2
tar -xf u-boot.tar.bz2
cd u-boot-2026.01
for p in /Users/sue/code/CoreELEC-official/projects/Amlogic/devices/AMLGX/patches/u-boot/*.patch; do
  patch -p1 --batch --forward < "$p" >/tmp/uboot-patchcheck.log 2>&1 || { cat /tmp/uboot-patchcheck.log; exit 1; }
done
echo PATCH_CHECK_OK
```

Expected: `PATCH_CHECK_OK`

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/u-boot
git commit -m "fix(u-boot): drop upstreamed amlgx board patches"
```

### Task 4: Keep the N1 Linux Side Minimal and Board-Specific

**Files:**
- Modify if needed: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`
- Modify if needed: `packages/linux-firmware/brcmfmac_sdio-firmware/package.mk`
- Modify if needed: `packages/linux-firmware/brcmfmac_sdio-firmware/files/brcm/brcmfmac43455-sdio.phicomm,n1.txt`

**Step 1: Write the failing test**

Run:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
```

Expected: if the build fails after U-Boot host tools are fixed, the next blocker should be a real N1-specific kernel, DTS, or firmware issue.

**Step 2: Verify the next failure**

Run the build and capture the first failing package.

Expected: one concrete N1-related blocker.

**Step 3: Minimal implementation**

- Only change the N1 DTS patch or N1 firmware data required to clear the first real N1 blocker.
- Avoid broad AMLGX defaults unless the blocker cannot be isolated to N1 files.
- Do not reintroduce unrelated board support.

**Step 4: Verify**

Re-run:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
```

Expected: build progresses beyond the previous failure point.

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch packages/linux-firmware/brcmfmac_sdio-firmware/package.mk packages/linux-firmware/brcmfmac_sdio-firmware/files/brcm/brcmfmac43455-sdio.phicomm,n1.txt
git commit -m "fix(amlogic): advance phicomm n1 bring-up"
```

### Task 5: Add Fast Pre-CI Guards for N1

**Files:**
- Modify if needed: `.github/workflows/build-phicomm-n1.yml`
- Create if needed: `tools/check-phicomm-n1-prereqs.sh`

**Step 1: Write the failing test**

Identify checks that would have caught the old failure before a full image build:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 config
```

Expected: these pass; if a future regression breaks them, CI should fail early.

**Step 2: Verify current behavior**

Run the commands above.

Expected: both succeed.

**Step 3: Minimal implementation**

- Add a fast CI precheck step or small local script that validates:
  - N1 helper DTB lookup
  - N1 helper config lookup
  - optional U-Boot patch dry-run if runtime is acceptable

**Step 4: Verify**

Run the script or CI step locally.

Expected: exit 0 when the N1 build path is sane.

**Step 5: Commit**

```bash
git add .github/workflows/build-phicomm-n1.yml tools/check-phicomm-n1-prereqs.sh
git commit -m "ci: add fast phicomm n1 prechecks"
```

### Task 6: Real-Hardware Bring-Up After CI Produces an Image

**Files:**
- Modify if needed: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`

**Step 1: Write the failing test**

Boot the generated image on a real N1.

Collect:

```bash
cat /proc/device-tree/model
dmesg -T | tee /storage/dmesg-n1.log
journalctl -b | tee /storage/journal-n1.log
```

Expected: first failures are likely HDMI, Ethernet, USB, eMMC, reboot, or poweroff.

**Step 2: Verify the first hardware failure**

Run:

```bash
ip link
lsblk
```

Expected: at least one first-order subsystem may fail.

**Step 3: Minimal implementation**

- Fix one subsystem at a time in the N1 DTS patch only.
- Priority order:
  - boot to userspace
  - HDMI
  - Ethernet
  - USB
  - eMMC
  - reboot/poweroff

**Step 4: Verify**

Rebuild, boot, and re-test only the subsystem addressed.

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch
git commit -m "fix(amlogic): bring up phicomm n1 hardware"
```
