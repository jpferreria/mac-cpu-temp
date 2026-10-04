# cpu-temp

A lightweight, native macOS menu bar utility designed specifically for Apple Silicon (MacBook Air / Pro) that shows live CPU and SoC temperatures in Celsius with a compact thermometer icon.

![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%2F%20M2%20%2F%20M3%20%2F%20M4-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Menu Bar Display**: Displays live temperature (e.g. `45°C`) alongside an SF Symbol thermometer icon that dynamically shifts (`thermometer.low`, `thermometer.medium`, `thermometer.high`).
- **Zero Root / Sudo Required**: Directly interfaces with Apple Silicon's thermal management services via `IOHIDEventSystemClient` without requiring `sudo` or the battery-draining `powermetrics` daemon.
- **Fanless & Battery Friendly**: Consumes `< 0.1%` CPU and pauses automatically when the display or system sleeps (`NSWorkspaceScreensDidSleepNotification`).
- **Comprehensive Dropdown**:
  - Max CPU / SoC temperature.
  - Average SoC temperature.
  - Battery & storage (NAND) temperatures.
  - Per-sensor list with breakdown of all active die sensors.
  - Configurable update intervals (`1s`, `2s`, `5s`).
  - Unit toggle (`°C` / `°F`).
  - Launch at Login support.
- **Pure Accessory App**: Runs as a background agent (`LSUIElement = true`) with no clutter in your Dock or Cmd+Tab switcher.

---

## Building & Running

### Requirements
- macOS 12.0+ on Apple Silicon (M1, M2, M3, M4).
- Command Line Tools (`clang`).

### Build
```bash
make build
```

### Run
```bash
make run
```

### Install to `~/Applications`
```bash
make install
```

---

## Project Structure

```text
.
├── Makefile             # Build, run, and install targets
├── build.sh             # Build script compiling into cpu-temp.app bundle
├── Info.plist           # Bundle manifest (configured with LSUIElement = true)
├── cpu-temp-plan.md     # Architectural plan and roadmap
└── src/
    ├── main.m           # App initialization (accessory activation policy)
    ├── AppDelegate.h/m  # Menu bar status item, timer, dynamic menu & sleep handling
    ├── ThermalMonitor.h/m # IOHIDEventSystemClient bridge & sensor classification
    └── SensorInfo.h/m   # Sensor model & unit conversion
```
