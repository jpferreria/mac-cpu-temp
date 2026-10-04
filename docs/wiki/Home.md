# Welcome to the cpu-temp Wiki

**cpu-temp** is a native, ultra-lightweight macOS menu bar utility designed specifically for Apple Silicon (MacBook Air & MacBook Pro). It displays real-time CPU and SoC die temperatures in Celsius with a dynamic status bar icon.

---

## 📚 Table of Contents

- [Quick Start & Installation](Installation-&-Homebrew)
  - Installing via Homebrew Cask
  - Building from Source
  - Resolving Gatekeeper Warnings
- [Architecture & Sensors](Architecture-&-Sensors)
  - Apple Silicon Thermal Subsystem (`0xff00:0x5`)
  - How Sensors are Read Without Root
  - Comparison: `IOHIDEventSystemClient` vs `powermetrics` vs `AppleSMC`
- [Energy & Battery Optimization](Energy-&-Battery-Optimization)
  - Fanless MacBook Air Optimization
  - Sleep-Aware Polling Suspension
  - Coalesced Kernel Timers
- [Troubleshooting & FAQ](Troubleshooting-&-FAQ)
  - Icon Hidden Behind Display Notch
  - Launch at Login Permissions
  - Shell Profile `$USER` Issues

---

## ⚡ Quick Start

### Install via Homebrew
```bash
brew install --cask jpferreria/tap/cpu-temp
```

If you encounter macOS Gatekeeper's quarantine prompt when opening the app:
```bash
xattr -cr /Applications/cpu-temp.app
```

### Launch
```bash
open /Applications/cpu-temp.app
```
*(Or press `Cmd + Space` and search for **cpu-temp**).*
