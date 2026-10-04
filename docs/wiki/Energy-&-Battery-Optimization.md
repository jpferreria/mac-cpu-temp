# Energy & Battery Optimization

## Designed for Fanless MacBook Air

The MacBook Air does not have an active cooling fan. Background monitoring software that constantly burns CPU cycles creates heat, counteracting the very purpose of thermal monitoring.

`cpu-temp` incorporates multiple engineering safeguards to ensure near-zero energy consumption:

---

## 1. Zero-Polling Sleep Observers

`cpu-temp` listens for system and display sleep events via `NSWorkspace`:

- `NSWorkspaceScreensDidSleepNotification`
- `NSWorkspaceWillSleepNotification`

The instant your MacBook Air lid is closed or the display turns off, the update timer is completely invalidated. The application goes fully dormant and consumes **0% CPU** during sleep.

When the display or lid is opened (`NSWorkspaceScreensDidWakeNotification`), polling resumes immediately.

---

## 2. Kernel Timer Coalescing

Rather than waking the CPU at rigid timer boundaries, `cpu-temp` sets timer tolerance:

```objc
self.timer.tolerance = 0.5;
```

This allows the XNU kernel scheduler to align timer firing with existing OS wakeups, preventing unnecessary CPU wake events and preserving battery charge.

---

## 3. On-Demand Menu Generation

Rather than constantly updating UI strings for 40+ sensor channels in the background, `cpu-temp` uses:

```objc
- (void)menuNeedsUpdate:(NSMenu *)menu;
```

The detailed breakdown of P-cores, E-cores, storage, and battery is only formatted and computed when the user actively clicks the menu bar icon.
