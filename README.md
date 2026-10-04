# cpu-temp

A native, ultra-lightweight macOS menu bar utility designed specifically for Apple Silicon (MacBook Air & MacBook Pro). Displays real-time CPU and SoC die temperatures in Celsius with a dynamic status bar icon.

[![Platform: macOS](https://img.shields.io/badge/platform-macOS%2012.0%2B-blue.svg)](https://apple.com/macos)
[![Architecture: arm64](https://img.shields.io/badge/arch-Apple%20Silicon%20(M1--M4)-brightgreen.svg)]()
[![Permissions: Zero Root](https://img.shields.io/badge/permissions-zero%20root%20%2F%20no%20sudo-success.svg)]()
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

---

## Overview

Unlike older Intel Macs or battery-heavy command-line tools that rely on `sudo powermetrics`, **`cpu-temp`** directly queries Apple Silicon's hardware thermal sensors through `IOHIDEventSystemClient`. It runs entirely in user-space with **zero root privileges** and is engineered specifically to prevent battery drain on fanless MacBook Air laptops.

```text
[ Menu Bar Glance ]
┌──────────────────────────────────────────────┐
│  ...  [🔋 92%]  [📶]  [ 🌡️ 44°C ]  Sun Oct 4 │
└───────────────────────────┬──────────────────┘
                            │ (Click)
┌───────────────────────────▼──────────────────────────┐
│  cpu-temp  •  MacBook Air (Apple Silicon)            │
├──────────────────────────────────────────────────────┤
│  Max CPU Temp:       44.5°C                          │
│  Average SoC Temp:  41.2°C                          │
│  Battery Temp:       35.0°C                          │
│  Storage (NAND):    38.0°C                          │
├──────────────────────────────────────────────────────┤
│  SoC Sensors (24)                                  ▶ │
│  Other Sensors (19)                                ▶ │
├──────────────────────────────────────────────────────┤
│  Update Interval                                   ▶ │
│  Temperature Unit                                  ▶ │
│  ✓ Launch at Login                                   │
├──────────────────────────────────────────────────────┤
│  Refresh Now                                     ⌘R  │
│  Quit cpu-temp                                   ⌘Q  │
└──────────────────────────────────────────────────────┘
```

---

## Key Features

- **Menu Bar Display**: Real-time temperature readout (e.g., `45°C`) with an adaptive SF Symbol thermometer icon (`thermometer.low`, `thermometer.medium`, `thermometer.high`).
- **No Root / No `sudo` Needed**: Communicates directly with Apple's HID thermal services (`0xff00:0x5`) without running continuous background helper daemons.
- **Battery-Friendly (MacBook Air Optimized)**:
  - **< 0.1% CPU consumption** and **< 10 MB memory footprint**.
  - **Sleep Aware**: Listens to `NSWorkspaceScreensDidSleepNotification` and completely halts the timer when your display or MacBook lid is closed.
  - **Coalesced Wakeups**: Uses `NSTimer.tolerance` so the CPU does not wake unnecessarily.
- **Detailed Thermal Breakdown**:
  - Max and average CPU/SoC die temperatures.
  - Battery pack and storage (NAND flash) thermals.
  - Full per-sensor inspector submenu listing all active hardware channels (`PMU tdie*`, etc.).
- **Configurable Settings**:
  - Refresh rates: `1s` (Fast), `2s` (Default), or `5s` (Power Saver).
  - Units: Toggle between Celsius (`°C`) and Fahrenheit (`°F`).
  - Native Launch at Login integration via macOS `SMAppService`.
- **Pure Accessory Mode**: Configured with `LSUIElement = true`—runs silently in the status bar with zero clutter in your Dock or Cmd+Tab switcher.

---

## Technical Architecture

```mermaid
flowchart TD
    subgraph Hardware [Apple Silicon Hardware]
        SOC[SoC Die Sensors: PMU tdie1..14, PMU2 tdie1..10]
        BAT[Battery Gas Gauge]
        NAND[NAND Storage Temp]
    end

    subgraph Driver [IOKit / HID Subsystem]
        IOHID[IOHIDEventSystemClient (Page: 0xff00, Usage: 0x5)]
    end

    subgraph App [cpu-temp.app (User Space)]
        direction TB
        Bridge[ThermalMonitor (Dynamic Type-Safe Bridge)]
        Timer[Coalesced Dispatch Timer]
        UI[AppDelegate / NSStatusItem]
        Power[NSWorkspace Sleep & Wake Observers]
    end

    SOC & BAT & NAND --> IOHID
    IOHID --> Bridge
    Timer -->|Tick (1s / 2s / 5s)| Bridge
    Power -->|Pause / Resume| Timer
    Bridge -->|Filtered ThermalSnapshot| UI
```

### Why `IOHIDEventSystemClient`?
1. **`powermetrics`**: Requires `sudo` and spawns heavy sampling routines that defeat the purpose of monitoring a fanless MacBook Air.
2. **`AppleSMC`**: Deprecated on modern Apple Silicon architectures, with many sensor keys unpopulated.
3. **`IOHIDEventSystemClient`**: Fast (sub-millisecond sampling), official user-space framework, and provides granular per-sensor telemetry across the M1, M2, M3, and M4 generations.

---

## Security & Reliability Hardening

The codebase was audited and compiled with strict security measures:
- **Hardened Runtime**: Signed with macOS `codesign --options runtime` to satisfy modern Gatekeeper integrity.
- **Type-Safe CF Bridging**: Safely inspects CoreFoundation type IDs (`CFGetTypeID(val) == CFStringGetTypeID()`) prior to bridging to prevent objective-C selector crashes from driver anomalies.
- **Sanitized String & Buffer Handling**: Zeroed `sysctl` buffers with enforced null termination, and fallback protection against format string attacks.
- **Thread Synchronization**: Guarded with `@synchronized (self)` to prevent race conditions during rapid sleep/wake transitions.
- **Compiler Protections**: Built with `-Wall -Wextra -Wformat=2 -Wformat-security -fstack-protector-strong -D_FORTIFY_SOURCE=2`.

---

## Installation & Usage

### Prerequisites
- macOS 12.0 Monterey or newer (tested through macOS 15+ / 27.0).
- Apple Silicon Mac (`arm64`: M1, M2, M3, M4).
- Xcode Command Line Tools (`xcode-select --install`).

### Build
Compile the application bundle:
```bash
make build
```
This produces `build/cpu-temp.app`.

### Run
Launch the application directly in the menu bar:
```bash
make run
```

### Install
Copy to your user applications folder (`~/Applications`):
```bash
make install
```
Once installed, `cpu-temp` is immediately searchable in **Spotlight** or **Raycast** (`Cmd + Space` &rarr; type `cpu-temp`).

### Uninstall
Remove the application bundle:
```bash
make uninstall
```

---

## Project Structure

```text
.
├── Makefile                # Build, run, install, uninstall, and clean targets
├── build.sh                # Hardened build script creating cpu-temp.app
├── Info.plist              # Bundle metadata (LSUIElement = true)
├── README.md               # Documentation and architecture guide
├── cpu-temp-plan.md        # Architectural roadmap and design decisions
└── src/
    ├── main.m              # App bootstrap and accessory activation policy
    ├── AppDelegate.h/m     # Menu bar item, dynamic dropdown, and sleep observer
    ├── ThermalMonitor.h/m  # IOHID thermal sensor scanner & classifier
    └── SensorInfo.h/m      # Sensor model and temperature unit formatting
```

---

## Troubleshooting

- **Icon not visible in menu bar?**
  If your menu bar has many icons or a MacBook display notch, macOS may hide trailing status items. Hold `Cmd` and drag `cpu-temp` to the right side of the menu bar.
- **How to quit?**
  Click the `cpu-temp` icon in the menu bar and select **Quit cpu-temp** or press `⌘Q`.
- **Does it require internet access?**
  No. `cpu-temp` makes zero network requests and does not link any network frameworks.

---

## License

Released under the [MIT License](LICENSE).
