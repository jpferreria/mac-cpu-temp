# Architecture & Sensors

## 1. Overview
Unlike older Intel Macs or battery-draining command-line utilities, **`cpu-temp`** directly interfaces with the Apple Silicon hardware telemetry layer via user-space **`IOHIDEventSystemClient`** APIs.

---

## 2. The Apple Silicon Thermal Subsystem

Apple Silicon M-series chips (M1 through M4) expose hardware thermal monitors through the Human Interface Device (HID) framework using proprietary Apple vendor usage codes:

- **Usage Page**: `0xff00` (Apple Vendor Specific Page)
- **Primary Usage**: `0x0005` (Thermal / Temperature Telemetry)
- **Event Type**: `15` (`kIOHIDEventTypeTemperature`)
- **Field Base**: `15 << 16` (`IOHIDEventFieldBase(kIOHIDEventTypeTemperature)`)

### Why Not `powermetrics`?
- Requires `sudo` / root credentials.
- Spawns a background tracing daemon that actively taxes the CPU and drains battery.

### Why Not `AppleSMC`?
- Traditional SMC keys (like `TC0P`, `TC0D`) were designed for Intel architecture.
- Deprecated on modern Apple Silicon macOS systems, leaving most sensor registers empty or inaccessible.

### Why `IOHIDEventSystemClient`?
- **Zero Root Needed**: Executes entirely within normal user-space application permissions.
- **Microsecond Latency**: Querying hardware registers takes less than 0.1 milliseconds per poll.
- **Granular Sensor Telemetry**: Exposes 40+ independent hardware channels across the SoC die, battery, and storage.

---

## 3. Sensor Classification

The `ThermalMonitor` engine continuously categorizes sensor channels into logical hardware groups:

| Category | Sensor Patterns | Hardware Component |
| :--- | :--- | :--- |
| **SoC Die / CPU** | `PMU tdie*`, `PMU2 tdie*`, `SOC*`, `ACC*` | CPU Performance (P-Cores), Efficiency (E-Cores), GPU, Neural Engine |
| **Battery** | `gas gauge battery` | Internal lithium-ion battery pack temperature |
| **Storage** | `NAND CH0 temp` | NVMe / NAND flash storage controller |
| **Other** | `PMU tdev*`, `PMU tcal` | Peripheral power management units, ambient board sensors |

*Note: Calibration thresholds (`tcal`) are intentionally filtered out of CPU peak calculations to prevent artificial skewing of active core readings.*
