# Phicomm N1 on CoreELEC 22 Design

## Goal

Port the latest `coreelec-22` Amlogic stack to the Phicomm N1 as a fresh-install target that users can boot from removable media and reflash or reinstall from scratch.

## Current State

- The existing community N1 fork is based on `CoreELEC 21` and `projects/Amlogic-ce/devices/Amlogic-ng`.
- That path uses the legacy `amlogic-4.9` vendor kernel and N1-specific logic in:
  - `projects/Amlogic-ce/devices/Amlogic-ng/options`
  - `projects/Amlogic-ce/devices/Amlogic-ng/packages/u-boot-Phicomm_N1/package.mk`
  - `projects/Amlogic-ce/devices/Amlogic-ng/bootloader/update.sh`
- The current official tree uses the newer `projects/Amlogic/devices/AMLGX` path with the mainline `amlogic` kernel package.
- Official `coreelec-22` explicitly blocks in-place upgrades from `4.9` vendor-kernel installs, so the new N1 target must be treated as a new install path rather than an upgrade path.

## Decision Summary

Build N1 support on the `projects/Amlogic/devices/AMLGX` path, not by reviving or extending the old `Amlogic-ng` flow.

For the first bootable version:

- Reuse the N1 vendor boot chain and removable-media boot flow.
- Do not require a custom board-specific U-Boot flash path.
- Add a board-specific `phicomm-n1` image target that preselects the correct DTB.
- Add N1 support to the Linux patch stack as a new mainline-style DTS derived from the existing GXL/S905D board family.

## Architecture

### Build-System Integration

The new target will live in the official `Amlogic/AMLGX` project.

- Add `phicomm-n1` to `scripts/uboot_helper`.
- Route `UBOOT_SYSTEM=phicomm-n1` through the existing Amlogic boot image logic.
- Keep the install path equivalent to `box` for the first version so the image depends on the N1's existing vendor bootloader instead of introducing a new U-Boot flashing risk.

This gives the image a stable board identity and a deterministic DTB selection without requiring early work on a dedicated U-Boot port.

### Kernel and Device Tree

The hardware description should be added as a new mainline-style DTS in the Amlogic Linux patch stack.

- Base the new board on the current `meson-gxl-s905d-p230` family, not on the old vendor-only `coreelec-gxl` tree.
- Carry over only the verified board differences from the old N1 DTS:
  - `compatible = "phicomm,n1", "amlogic,s905d", "amlogic,meson-gxl"`
  - `model = "Phicomm N1"`
  - force the OTG port into host mode
  - disable CVBS if still appropriate on the mainline tree
- Keep the first DTS minimal. Anything not proven to differ from the `p230` baseline stays inherited until hardware testing shows otherwise.

### Boot Flow

The first implementation should prefer the lowest-risk path:

1. Build a board-specific image named with `UBOOT_SYSTEM=phicomm-n1`.
2. Copy the N1 DTB into the image boot partition.
3. Generate boot configuration that points directly at `meson-gxl-s905d-phicomm-n1.dtb`.
4. Reuse the existing autoscript path that the N1 vendor bootloader already understands.

This avoids the biggest early risk: shipping a new U-Boot image before the kernel and DTS are proven stable on real hardware.

## Validation Strategy

### Phase 1: First Boot

The first milestone is narrow:

- boot from SD or USB
- load the N1 DTB automatically
- mount the system and storage partitions
- reach userspace
- start Kodi

### Phase 2: First-Order Hardware

After boot is stable, validate:

- HDMI display
- Ethernet
- USB host
- eMMC visibility
- reboot and poweroff

These are release blockers for a "fresh install" image.

### Phase 3: Media Path

Then validate:

- Kodi UI stability
- video decode
- HDMI audio
- CEC
- common 1080p and 4K playback paths

### Phase 4: Second-Tier Peripherals

Treat these as follow-up bring-up unless they block first boot:

- Wi-Fi
- Bluetooth
- IR
- LEDs

## Non-Goals

- No support for in-place upgrades from the old `Amlogic-ng` or `4.9` N1 builds.
- No requirement to preserve the old `installtoemmc` or `installtointernal` behavior in the first release.
- No requirement to introduce a custom N1 U-Boot flashing flow in the first release.

## Main Risks

### DTS Drift

The old N1 port is based on a vendor kernel board file, while the new port must live on the mainline `AMLGX` patch stack. Some vendor-only details may not map 1:1.

### Boot-Chain Assumptions

The image must boot cleanly with the N1's existing vendor chain. If the generic autoscript path behaves differently on real hardware, the first iteration may need small boot-script adjustments.

### Peripheral Differences

Wi-Fi, Bluetooth, IR, and LEDs are the most likely areas to require follow-up work outside the minimal DTS.

## Acceptance Criteria

The first successful port is acceptable when all of the following are true:

- `PROJECT=Amlogic DEVICE=AMLGX UBOOT_SYSTEM=phicomm-n1 make image` produces a flashable image.
- The image boots on a real Phicomm N1 from removable media without manual DTB edits.
- Kodi starts successfully.
- HDMI, Ethernet, USB, eMMC detection, reboot, and poweroff all work.

