# Troubleshooting & FAQ

## 1. Icon is Missing or Not Visible in Menu Bar

**Cause**: On modern MacBooks with a display camera notch (MacBook Air M2/M3/M4, MacBook Pro 14"/16"), macOS automatically hides menu bar items when there are too many open menu bar applications.

**Solution**:
- Hold the `Command (⌘)` key, click any existing menu bar icon, and drag it left or right to rearrange.
- Close unused menu bar apps to free up space to the right of the notch.

---

## 2. Gatekeeper "Unverified Developer" Alert

**Cause**: The application was downloaded from GitHub/Homebrew without an Apple Developer ID signature ($99/year).

**Solution**:
```bash
xattr -cr /Applications/cpu-temp.app
```

---

## 3. Homebrew reports "user doesn't exist"

**Cause**: If your shell profile (`~/.zshrc`) contains an invalid `$USER` assignment (e.g. `export USER="something!"`), Homebrew cannot match it to a local macOS account.

**Solution**:
Remove or comment out the `export USER=...` line in `~/.zshrc`, or run Homebrew with:
```bash
USER=$(whoami) brew install --cask jpferreria/tap/cpu-temp
```

---

## 4. How to Completely Uninstall

```bash
brew uninstall --cask cpu-temp
```
*(Or delete `/Applications/cpu-temp.app`).*
