# Installation & Homebrew

## 1. Installing via Homebrew Cask (Recommended)

`cpu-temp` is distributed as a native Homebrew Cask via the official custom tap:

```bash
brew install --cask jpferreria/tap/cpu-temp
```

### Trusting the Tap
Homebrew may display a notice regarding untrusted third-party taps. To approve the tap:
```bash
brew trust jpferreria/tap
```

---

## 2. Resolving Gatekeeper Warnings

Because `cpu-temp` is an open-source binary built on GitHub Actions without an Apple Developer subscription ($99/yr), macOS attaches the quarantine attribute upon downloading:

```text
Apple could not verify “cpu-temp” is free of malware that may harm your Mac...
```

### Quick Terminal Fix:
Remove the quarantine extended attribute:
```bash
xattr -cr /Applications/cpu-temp.app
```

### GUI Alternative:
Go to **System Settings** &rarr; **Privacy & Security** &rarr; scroll to **Security** &rarr; click **Open Anyway**.

---

## 3. Building From Source

If you prefer building locally:

```bash
# 1. Clone repository
git clone https://github.com/jpferreria/mac-cpu-temp.git
cd mac-cpu-temp

# 2. Build and install to ~/Applications
make install

# 3. Launch
open ~/Applications/cpu-temp.app
```
