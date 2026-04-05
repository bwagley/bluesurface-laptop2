#!/bin/bash
# Surface Laptop 2 — rebind OV9734 after IPU3 CIO2 binds
# Triggered by udev rule 99-ov9734-rebind.rules
#
# The OV9734 sensor probes before ipu_bridge has created the fwnode graph,
# leaving it stuck in waiting_for_supplier. This script rebinds the sensor
# after CIO2 has loaded so the fwnodes exist and probe can succeed.

sleep 1

DRIVER_PATH="/sys/bus/i2c/drivers/ov9734"

# Find the OV9734 device — it's ACPI-enumerated as i2c-OVTI9734:00,
# not a numeric bus address like 2-0036.
I2C_DEV=""
for dev in "$DRIVER_PATH"/i2c-OVTI9734*; do
    if [[ -e "$dev" ]]; then
        I2C_DEV=$(basename "$dev")
        break
    fi
done

# Fallback: search sysfs if not already bound to the driver
if [[ -z "$I2C_DEV" ]]; then
    for dev in /sys/bus/i2c/devices/i2c-OVTI9734*; do
        if [[ -e "$dev" ]]; then
            I2C_DEV=$(basename "$dev")
            break
        fi
    done
fi

if [[ -z "$I2C_DEV" ]]; then
    echo "ipu3-camera-rebind: OV9734 device not found" >&2
    exit 1
fi

echo "ipu3-camera-rebind: rebinding $I2C_DEV" >&2

# Unbind if currently bound
if [[ -e "$DRIVER_PATH/$I2C_DEV" ]]; then
    echo "$I2C_DEV" > "$DRIVER_PATH/unbind" 2>/dev/null || true
    sleep 0.5
fi

echo "$I2C_DEV" > "$DRIVER_PATH/bind" 2>/dev/null || true
