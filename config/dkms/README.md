# DKMS Module Sources

The `ipu-bridge-ov9734/` and `ov9734-surface/` directories are **not checked
into this repo**. They are cloned automatically from
[tomgood18/surface-laptop-2-camera](https://github.com/tomgood18/surface-laptop-2-camera)
the first time you run `./build.sh`.

Any local fixes live in `patches/` and are applied automatically after cloning.

The `v4l2loopback/` directory **is** checked in — it is not part of the camera
repo.

### Manual setup (if needed)

```bash
git clone https://github.com/tomgood18/surface-laptop-2-camera.git /tmp/cam
cp -r /tmp/cam/dkms/ipu-bridge-ov9734 config/dkms/
cp -r /tmp/cam/dkms/ov9734-surface    config/dkms/

# Apply patches
for p in patches/*.patch; do patch -d config -p1 < "$p"; done
```
