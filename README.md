# bluesurface-laptop2

Custom Fedora Atomic (Silverblue) OCI image for the Surface Laptop 2, built with `podman` and deployed via `bootc switch` / `rpm-ostree rebase`.

Bundles the [linux-surface](https://github.com/linux-surface/linux-surface) kernel, pre-compiled camera kernel modules from [tomgood18/surface-laptop-2-camera](https://github.com/tomgood18/surface-laptop-2-camera), and performance tuning for the hardware.

## What's in the image

| Layer | Details |
|-------|---------|
| Base | [ublue-os/silverblue-main](https://github.com/ublue-os/main) (Fedora 43) |
| Kernel | `kernel-surface` — touch, pen, trackpad, power management |
| Camera modules | `ipu_bridge`, `ov9734`, `v4l2loopback` — pre-compiled and Secure Boot signed |
| Surface daemons | `iptsd`, `libwacom-surface` |
| Tuning | ZRAM swap (8 GB), btrfs zstd:1 compression, camera udev/modprobe rules |

Camera kernel modules are compiled into the image at build time because DKMS cannot run on an immutable filesystem. The module sources are fetched from upstream automatically by `build.sh`, with local fixes applied from `patches/`.

For the **userspace camera bridge** (required to actually use the webcam), see [bwagley/surface-laptop-2-camera-userspace](https://github.com/bwagley/surface-laptop-2-camera-userspace).

## Prerequisites

**Build workstation** (any Linux box):
- `podman` (or `docker`)
- A GitHub account with a Personal Access Token (`write:packages` scope)

**Target device:**
- Surface Laptop 2 running Fedora Silverblue 43+ (or any Fedora Atomic Desktop)

## Setup

```bash
git clone https://github.com/YOUR_USERNAME/bluesurface-laptop2.git
cd bluesurface-laptop2

cp .env.example .env
# Edit .env — set GITHUB_USER to your GitHub username

echo "YOUR_TOKEN" | podman login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

If Secure Boot is enabled, generate a MOK signing key pair (one-time):

```bash
./generate-mok.sh
```

## Build and push

```bash
./build.sh              # build and push
./build.sh --build-only # build without pushing
./build.sh --no-cache   # full rebuild
```

On first run, camera DKMS sources are cloned from [tomgood18/surface-laptop-2-camera](https://github.com/tomgood18/surface-laptop-2-camera) and patched automatically.

## Deploy

On the Surface Laptop 2:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/bluesurface-laptop2:latest
systemctl reboot
```

If Secure Boot is enabled, the first reboot will show a blue MOK Manager screen. Select **Enroll MOK**, confirm, and enter the password `surface`.

After the image is running, set up the userspace camera bridge from [bwagley/surface-laptop-2-camera-userspace](https://github.com/bwagley/surface-laptop-2-camera-userspace).

## Updating

Rebuild and push from your workstation:

```bash
./build.sh
```

On the laptop:

```bash
rpm-ostree upgrade && systemctl reboot
```

## Customization

**Packages** — add to the `dnf5 install` lines in `Containerfile`. Prefer Flatpaks for user-facing apps.

## Troubleshooting

```bash
uname -r                                # should contain "surface"
lsmod | grep -E "ov9734|ipu_bridge"     # camera modules loaded?
dmesg | grep -E "ov9734|ipu3|OVTI"      # udev rebind working?
```

To roll back:

```bash
rpm-ostree rollback
systemctl reboot
```

If `rpm-ostree rebase` fails, ensure the GHCR package is public: GitHub → Packages → Package Settings → Change Visibility → Public.

## Related

- [linux-surface/linux-surface](https://github.com/linux-surface/linux-surface) — Surface kernel and firmware
- [tomgood18/surface-laptop-2-camera](https://github.com/tomgood18/surface-laptop-2-camera) — OV9734 camera kernel module sources
- [bwagley/surface-laptop-2-camera-userspace](https://github.com/bwagley/surface-laptop-2-camera-userspace) — Userspace camera bridge and service
