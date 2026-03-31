# Phicomm N1 CoreELEC 22 Port Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a bootable `coreelec-22` image for Phicomm N1 on the new `Amlogic/AMLGX` stack that users can flash and reinstall from removable media.

**Architecture:** Add a new `phicomm-n1` board target to the official `AMLGX` image flow, but keep the bootloader install path equivalent to `box` for the first version so the N1 can keep using its vendor boot chain. Add the board itself through a new Linux DTS patch derived from the `meson-gxl-s905d-p230` family, then iterate only on the hardware issues reproduced on real devices.

**Tech Stack:** CoreELEC build system, `projects/Amlogic`, `AMLGX` device flow, mainline Linux `6.19` patch stack, Amlogic boot scripts, DTS patching, Kodi.

---

### Task 1: Add a Board-Specific N1 Image Target Without Introducing New U-Boot Flashing

**Files:**
- Modify: `scripts/uboot_helper`
- Modify: `projects/Amlogic/bootloader/install`
- Modify: `projects/Amlogic/bootloader/mkimage`

**Step 1: Write the failing test**

Run:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
```

Expected: non-zero exit because `phicomm-n1` is not yet a known `AMLGX` board.

**Step 2: Run the test to verify it fails**

Run:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
echo $?
```

Expected: no DTB is printed and the exit code is non-zero.

**Step 3: Write the minimal implementation**

- In `scripts/uboot_helper`, add a new `AMLGX` board named `phicomm-n1`:

```python
'phicomm-n1': {
    'dtb': 'meson-gxl-s905d-phicomm-n1.dtb',
    'config': 'p212_defconfig'
},
```

- In `projects/Amlogic/bootloader/install`, treat `phicomm-n1` like `box` for the first revision so the installer does not try to ship or flash a new board-specific U-Boot payload:

```sh
case "${UBOOT_SYSTEM}" in
  box|phicomm-n1|"")
    # no-op, use vendor bootloader
    ;;
  *)
    ...
    ;;
esac
```

- In `projects/Amlogic/bootloader/mkimage`, add a `phicomm-n1` case that reuses the removable-media autoscript path but writes a fixed N1 DTB into `uEnv.ini` instead of the generic `@@DTB_NAME@@` placeholder:

```sh
  phicomm-n1)
    mkimage_uEnv
    mkimage_autoscripts
    mkimage_bootini
    mkimage_dtb
    ;;
```

Use the `DTB` already provided by `scripts/mkimage` from `scripts/uboot_helper`. Do not overwrite it with `@@DTB_NAME@@` in this branch.

**Step 4: Run the verification**

Run:

```bash
./scripts/uboot_helper Amlogic AMLGX phicomm-n1 dtb
```

Expected: `meson-gxl-s905d-phicomm-n1.dtb`

**Step 5: Commit**

```bash
git add scripts/uboot_helper projects/Amlogic/bootloader/install projects/Amlogic/bootloader/mkimage
git commit -m "feat(amlogic): add phicomm n1 image target"
```

### Task 2: Add the Linux Device Tree for Phicomm N1

**Files:**
- Create: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`
- Reference: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0064-WIP-arm64-dts-amlogic-p230-fix-IRQ-for-external-PHY.patch`
- Reference: inspect the existing Phicomm N1 packaging in `projects/Amlogic-ce/devices/Amlogic-ng/packages/u-boot-Phicomm_N1/package.mk` for board-specific source and naming conventions

**Step 1: Write the failing test**

Run:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
```

Expected: the build fails because `meson-gxl-s905d-phicomm-n1.dtb` does not exist in the kernel patch stack yet.

**Step 2: Run the test to verify it fails**

Run:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
```

Expected: failure during the boot artifact or DTB copy stage mentioning the missing `meson-gxl-s905d-phicomm-n1.dtb`.

**Step 3: Write the minimal implementation**

Create a patch that:

- adds `arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dts`
- adds the new DTB to the Amlogic DTS `Makefile`
- derives from the current `meson-gxl-s905d-p230` family
- carries only the verified N1 board deltas first

The initial DTS body should look like this:

```dts
/dts-v1/;

#include "meson-gxl-s905d-p230.dts"

/ {
	compatible = "phicomm,n1", "amlogic,s905d", "amlogic,meson-gxl";
	model = "Phicomm N1";

	cvbs-connector {
		status = "disabled";
	};
};

&usb0 {
	dr_mode = "host";
};
```

If the exact node names differ in the current mainline tree, adapt the patch to the existing `AMLGX` DTS structure rather than forcing vendor-kernel naming into the patch.

**Step 4: Run the verification**

Run:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
```

Expected: the build completes and produces an image artifact under `target/` with `phicomm-n1` in the name.

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch
git commit -m "feat(amlogic): add phicomm n1 device tree"
```

### Task 3: Verify the Boot Artifact Selects the N1 DTB Automatically

**Files:**
- Modify if needed: `projects/Amlogic/bootloader/mkimage`
- Modify if needed: `projects/Amlogic/bootloader/scripts/s905_autoscript.src`
- Modify if needed: `projects/Amlogic/bootloader/scripts/aml_autoscript.src`

**Step 1: Write the failing test**

Build an image and inspect the generated boot files.

Run:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
ls -1 target | grep phicomm-n1
```

Expected: the image exists, but if boot-file inspection shows `@@DTB_NAME@@` or a generic DTB path anywhere in the removable-media boot flow, treat that as a failure.

**Step 2: Run the test to verify it fails if the DTB is still generic**

Inspect the boot files produced by the image build and confirm that the selected DTB path is `meson-gxl-s905d-phicomm-n1.dtb`.

Expected: if any generated boot file still relies on the generic placeholder, stop and fix the boot script path before testing on hardware.

**Step 3: Write the minimal implementation**

Only if the artifact inspection fails:

- adjust `projects/Amlogic/bootloader/mkimage` so `phicomm-n1` always writes the fixed N1 DTB to `uEnv.ini`
- adjust the autoscript sources only if the N1 vendor boot chain requires a different file-loading order than the current `box` flow

Do not add board-specific script branches unless hardware testing proves they are required.

**Step 4: Run the verification**

Rebuild:

```bash
PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image
```

Expected: the finished image contains boot configuration that points directly at the N1 DTB without manual editing after flashing.

**Step 5: Commit**

```bash
git add projects/Amlogic/bootloader/mkimage projects/Amlogic/bootloader/scripts/s905_autoscript.src projects/Amlogic/bootloader/scripts/aml_autoscript.src
git commit -m "fix(amlogic): select phicomm n1 dtb in boot artifacts"
```

### Task 4: Boot on Real Hardware and Fix First-Order Bring-Up Issues

**Files:**
- Modify: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`
- Modify if needed: `projects/Amlogic/options`

**Step 1: Write the failing test**

Flash the image to removable media and boot a real N1 with a serial console attached.

Expected failure cases to capture explicitly:

- no video output
- no serial output after the boot script hands off to the kernel
- kernel panic before the root filesystem mounts
- Kodi never starts

**Step 2: Run the test to verify it fails**

On the device, capture:

```bash
dmesg -T | tee /storage/dmesg-firstboot.log
journalctl -b | tee /storage/journal-firstboot.log
cat /proc/device-tree/model
```

Expected: if boot is not stable, the logs show the first blocker clearly enough to drive a single DTS or boot-flow fix.

**Step 3: Write the minimal implementation**

Use only the smallest fix needed to clear the first blocker, starting in the DTS patch:

- wrong USB OTG mode: fix the USB controller mode in the DTS
- missing HDMI output: compare the inherited display nodes against the working `p230` baseline
- incorrect board identification: fix the top-level `compatible` or `model`

Avoid adding broad Amlogic-wide defaults in `projects/Amlogic/options` unless the failure cannot be fixed in the N1 DTS.

**Step 4: Run the verification**

Rebuild and retest until the device:

- boots from removable media
- reaches userspace
- starts Kodi
- reports `Phicomm N1` from `/proc/device-tree/model`

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch projects/Amlogic/options
git commit -m "fix(amlogic): boot phicomm n1 on aml gx"
```

### Task 5: Validate Ethernet, eMMC, USB, Reboot, and Poweroff

**Files:**
- Modify: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`

**Step 1: Write the failing test**

On a booted N1, run:

```bash
ip link
ethtool eth0
lsblk
ls /sys/bus/mmc/devices
reboot
poweroff
```

Expected: at least one of these checks may fail on the first hardware pass.

**Step 2: Run the test to verify it fails**

Reproduce the first failing subsystem and capture its logs:

```bash
dmesg -T | grep -Ei "eth|stmmac|phy|mmc|sdhci|usb"
```

Expected: the logs point at a DTS mismatch, not a generic framework issue.

**Step 3: Write the minimal implementation**

Patch only the N1 DTS for the broken subsystem:

- Ethernet: PHY mode, reset GPIO, interrupt wiring, or timing values
- eMMC or SD: bus width, voltage capabilities, card-detect wiring, or assigned clocks
- USB: host-mode or power-control wiring
- reboot or poweroff: PMIC or AO-domain node mismatch

Do not split these into new patch files unless the existing DTS patch becomes unreadable.

**Step 4: Run the verification**

Retest until all of these pass on hardware:

- `eth0` comes up and gets link
- eMMC is visible when present
- USB storage enumerates
- `reboot` returns to the bootloader cleanly
- `poweroff` actually powers the device down

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch
git commit -m "fix(amlogic): bring up phicomm n1 core peripherals"
```

### Task 6: Validate Media, Audio, and Kodi Runtime

**Files:**
- Modify if needed: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`
- Modify if needed: `projects/Amlogic/options`
- Modify only if reproduced: `projects/Amlogic/patches/alsa-lib/amlogic-0001-conf-add-support-for-Amlogic-AIU-and-AXG-cards.patch`

**Step 1: Write the failing test**

On the device, test:

```bash
aplay -l
cat /sys/class/drm/card0-HDMI-A-1/status
cat /sys/kernel/debug/cec/cec0/status
```

Then in Kodi, play:

- one 1080p H.264 file
- one 4K HEVC file
- one HDMI audio sample

Expected: any failure here is a release blocker for the first public image.

**Step 2: Run the test to verify it fails**

Capture logs for the first failure:

```bash
journalctl -b | grep -Ei "kodi|drm|hdmi|alsa|cec|vdec"
```

Expected: the failing area is narrowed to DTS wiring, ALSA card mapping, or a project-wide Amlogic default.

**Step 3: Write the minimal implementation**

- Fix DTS-level HDMI or audio wiring in the N1 patch first.
- Touch `projects/Amlogic/options` only if a project-wide default must change for AMLGX.
- Touch the ALSA patch only if the board exposes a card-name mismatch that blocks Kodi audio on N1.

**Step 4: Run the verification**

Retest until:

- HDMI reports connected correctly
- Kodi starts without display or audio regressions
- video playback is stable
- HDMI audio works
- CEC is at least detected without kernel errors

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch projects/Amlogic/options projects/Amlogic/patches/alsa-lib/amlogic-0001-conf-add-support-for-Amlogic-AIU-and-AXG-cards.patch
git commit -m "fix(amlogic): validate phicomm n1 media path"
```

### Task 7: Bring Up Wi-Fi, Bluetooth, IR, and Final Docs

**Files:**
- Modify if needed: `projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch`
- Modify if needed: `projects/Amlogic/config/kernel-firmware.dat`
- Modify if needed: `projects/Amlogic/options`
- Modify: `projects/Amlogic/README.md`
- Modify: `README.md`
- Create: `docs/boards/phicomm-n1.md`

**Step 1: Write the failing test**

On the device, test:

```bash
rfkill list
bluetoothctl list
ir-keytable
```

Expected: one or more of Wi-Fi, Bluetooth, or IR may still be missing in the first bootable image.

**Step 2: Run the test to verify it fails**

Capture the failure source:

```bash
dmesg -T | grep -Ei "brcm|wifi|bluetooth|hci|ir|remote"
```

Expected: identify whether the issue is firmware packaging, DTS wiring, or missing runtime defaults.

**Step 3: Write the minimal implementation**

- Fix DTS wiring if the peripheral is present but not described correctly.
- Add missing firmware packaging only if the kernel driver loads but firmware is absent.
- Update `docs/boards/phicomm-n1.md` with:
  - supported install method
  - known working hardware
  - known missing features
  - exact build command
- Add a short N1 note to `projects/Amlogic/README.md` and top-level `README.md` only if the project already uses those files for device support notes.

**Step 4: Run the verification**

Retest until the final support matrix is explicit:

- working now
- known broken
- deferred for later

The documentation must match the actual hardware state, not the intended state.

**Step 5: Commit**

```bash
git add projects/Amlogic/devices/AMLGX/patches/linux/amlogic-0100-WIP-arm64-dts-amlogic-add-phicomm-n1-support.patch projects/Amlogic/config/kernel-firmware.dat projects/Amlogic/options projects/Amlogic/README.md README.md docs/boards/phicomm-n1.md
git commit -m "docs(amlogic): document phicomm n1 support"
```
