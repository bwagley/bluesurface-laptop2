## ==========================================================================
## Surface Laptop 2 — Custom Fedora Atomic Image
## ==========================================================================
## Base: ublue silverblue-main (stock GNOME + ublue quality-of-life)
## Kernel: linux-surface (touch, pen, trackpad, power management)
## Camera: OV9734 fix (ipu_bridge + ov9734 + v4l2loopback DKMS modules)
## ==========================================================================

FROM ghcr.io/ublue-os/silverblue-main:43

## ---------- 1. Add linux-surface repo ----------
RUN dnf5 -y config-manager addrepo \
        --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo

## ---------- 2. Swap kernel ----------
## silverblue-main ships only the stock Fedora kernel — no ZFS, Framework,
## or akmods baggage to clean up. We use rpm --erase --nodeps because
## rpm-ostree marks kernel-core as protected.
##
## DEBUGGING TIP: If this step fails after a base image update, run:
##   podman run --rm ghcr.io/ublue-os/silverblue-main:43 rpm -qa | sort | grep -E 'kernel|libwacom'
## and add any new packages to the remove list.
RUN for pkg in kernel kernel-core kernel-modules kernel-modules-core \
               kernel-modules-extra; do \
        rpm --erase "$pkg" --nodeps 2>/dev/null || true; \
    done && \
    dnf5 -y install --allowerasing \
        kernel-surface \
        iptsd \
        libwacom-surface \
        libwacom-surface-data \
        surface-secureboot && \
    dnf5 clean all

## ---------- 3. Camera system dependencies ----------
## v4l2loopback is built from source in step 5 (stock package is tied to
## stock kernel). The camera bridge uses GStreamer for the virtual camera.
RUN dnf5 -y install \
        v4l-utils \
        python3-numpy \
        python3-gobject \
        gstreamer1-plugins-base \
        gstreamer1-plugins-good && \
    dnf5 clean all

## ---------- 4. Camera: udev + modprobe + module autoload config ----------
COPY config/99-ov9734-rebind.rules   /etc/udev/rules.d/
COPY config/ipu3-camera-rebind.sh    /usr/local/sbin/
RUN chmod 755 /usr/local/sbin/ipu3-camera-rebind.sh
COPY config/v4l2loopback.conf        /etc/modprobe.d/
COPY config/surface-camera.conf      /etc/modules-load.d/

## ---------- 5. Camera: build + sign kernel modules ----------
## DKMS doesn't work at runtime on immutable systems, so we compile the three
## camera modules (ipu_bridge, ov9734, v4l2loopback) during the image build.
##
## Secure Boot requires modules to be signed. We use a persistent MOK key
## pair (generated once, stored locally, gitignored). Because the same public
## cert ships in every image, MOK enrollment is a ONE-TIME operation —
## you won't be prompted again after kernel or image updates.
COPY config/dkms/ /tmp/dkms-src/
COPY config/mok/mok.priv /tmp/mok.priv
COPY config/mok/mok.der  /tmp/mok.der

RUN dnf5 -y install kernel-surface-devel openssl && \
    dnf5 clean all && \
    # ── Convert DER cert to PEM for sign-file ──
    openssl x509 -inform DER -in /tmp/mok.der -out /tmp/mok.pem && \
    # ── Find the surface kernel version ──
    KVER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-surface-core | head -1) && \
    echo "Building camera modules for kernel: $KVER" && \
    # ── Build ipu-bridge-ov9734 (output is ipu_bridge.ko, note underscore) ──
    cd /tmp/dkms-src/ipu-bridge-ov9734 && \
    make -C /usr/src/kernels/$KVER M=$(pwd) modules && \
    install -Dm644 ipu_bridge.ko /usr/lib/modules/$KVER/updates/ipu_bridge.ko && \
    # ── Build ov9734-surface ──
    cd /tmp/dkms-src/ov9734-surface && \
    make -C /usr/src/kernels/$KVER M=$(pwd) modules && \
    install -Dm644 ov9734.ko /usr/lib/modules/$KVER/updates/ov9734.ko && \
    # ── Build v4l2loopback ──
    cd /tmp/dkms-src/v4l2loopback && \
    make -C /usr/src/kernels/$KVER M=$(pwd) modules && \
    install -Dm644 v4l2loopback.ko /usr/lib/modules/$KVER/updates/v4l2loopback.ko && \
    # ── Sign all three modules ──
    /usr/src/kernels/$KVER/scripts/sign-file sha256 /tmp/mok.priv /tmp/mok.pem \
        /usr/lib/modules/$KVER/updates/ipu_bridge.ko && \
    /usr/src/kernels/$KVER/scripts/sign-file sha256 /tmp/mok.priv /tmp/mok.pem \
        /usr/lib/modules/$KVER/updates/ov9734.ko && \
    /usr/src/kernels/$KVER/scripts/sign-file sha256 /tmp/mok.priv /tmp/mok.pem \
        /usr/lib/modules/$KVER/updates/v4l2loopback.ko && \
    # ── Install public cert for MOK enrollment ──
    install -Dm644 /tmp/mok.der /usr/share/surface-camera-mok/camera-modules.der && \
    # ── Regenerate module dependency map ──
    depmod $KVER && \
    # ── Clean up private key and build artifacts ──
    rm -f /tmp/mok.priv /tmp/mok.pem /tmp/mok.der && \
    rm -rf /tmp/dkms-src && \
    dnf5 -y remove kernel-surface-devel --setopt=clean_requirements_on_remove=True && \
    dnf5 clean all

## ---------- 6. Surface module autoload ----------
RUN echo -e "surface_aggregator\nsurface_hid_core\nsurface_kbd" \
    > /etc/modules-load.d/surface.conf

## ---------- 7. Remove bloat, add QOL----------
RUN dnf5 -y remove gnome-tour && dnf5 clean all
RUN dnf5 -y install vlc libreoffice && dnf5 clean all

## ---------- 8. Btrfs: lower zstd compression for speed ----------
## Default Fedora uses zstd:3. Level 1 is ~2x faster with minimal ratio loss,
## which matters on an older dual-core laptop. This remounts all btrfs mounts
## early in boot before anything writes significant data.
COPY config/btrfs-compression.service /usr/lib/systemd/system/
RUN systemctl enable btrfs-compression.service

## ---------- 9. ZRAM: tuned for 8 GB laptop running GNOME ----------
## zram-generator creates a compressed swap device in RAM. With ~3:1
## compression, 8 GB of zram gives ~24 GB effective swap — enough to keep
## GNOME responsive under memory pressure without hitting disk.
COPY config/zram-generator.conf /etc/systemd/zram-generator.conf
COPY config/zram-sysctl.conf    /etc/sysctl.d/99-zram.conf

## ---------- 10. Final validation + commit ----------
RUN bootc container lint
RUN ostree container commit
