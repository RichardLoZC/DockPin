<p><img src="Resources/AppIcon.png" width="96" alt="DockPin icon"></p>

# DockPin

Keep the macOS Dock at the bottom of the display you choose.

[简体中文](README.zh-CN.md) · [Download](https://github.com/RichardLoZC/DockPin/releases/latest) · [MIT License](LICENSE)

DockPin is a small, local menu bar utility for people whose Dock keeps jumping to another monitor. It preserves separate Spaces and uses the native macOS Dock. No subscription, account, or network connection is required.

## Features

- Pin the bottom Dock to the main display or a specific connected display.
- Hold **Option** to temporarily allow the Dock to move between displays.
- Pause or quit to remove the event filter immediately.
- Remember the preferred display by UUID; fall back to the main display while it is disconnected.
- Move the Dock back with an explicit menu action that yields when you move or click the mouse.
- Optional launch at login, disabled by default.
- Show whether the Dock is actually on the selected display, waiting to be moved, or missing permission.

## Requirements

- Apple Silicon Mac, macOS 14 or later.
- Two or more displays for locking.
- Dock position set to **Bottom**.
- **Displays have separate Spaces** enabled in System Settings → Desktop & Dock → Mission Control.
- **Accessibility** permission for DockPin. Screen Recording permission is not required.

The v1.0.0 interface is in Simplified Chinese. The release was tested on macOS 27.0.1 with a built-in display and a Nextend virtual display; other hardware and OS versions still need verification.

## Install

1. Download `DockPin-1.0.0-macos-arm64.zip` from [Releases](https://github.com/RichardLoZC/DockPin/releases/latest).
2. Extract it and move `DockPin.app` to `/Applications` or `~/Applications`.
3. Open DockPin and allow it in **System Settings → Privacy & Security → Accessibility**.
4. Click the menu bar pin. Under **固定到屏幕** (Pin to display), choose a display. The default follows the system's main display.
5. If the status says **等待 Dock 归位** (Waiting for Dock), push the pointer down against the chosen display's bottom edge, or choose **现在将 Dock 移回目标屏** (Move Dock back now).

The release is **ad-hoc signed and not notarized**. macOS may require approval in Privacy & Security before its first launch. You can also build the app from source. A changed local build may need Accessibility permission again.

| Menu item | Meaning |
| --- | --- |
| 固定 Dock | Enable or pause locking |
| 固定到屏幕 | Choose the target display |
| 现在将 Dock 移回目标屏 | Explicitly move the Dock back |
| 登录时启动 | Launch at login |
| 辅助功能权限… | Open Accessibility settings |
| 退出 DockPin | Quit and remove the filter |

Holding Option allows a temporary move. If the Dock remains on another display afterward, move it back manually or with the menu action.

## How it works and limitations

DockPin uses a public Quartz session event tap. It suppresses mouse movement and drag events within the bottom **4 desktop points** of non-target displays, preventing the edge gesture that normally summons the Dock there. It does not intercept clicks, scroll events, or keyboard events. Everything runs locally.

- Hover feedback, drag feedback, and hot corners within that narrow strip can be affected. Hold Option to bypass the filter.
- Only the **bottom** Dock is supported. Moving the Dock to the side pauses filtering.
- For vertically stacked displays, at least **8 horizontal desktop points** of the target's bottom edge must be exposed. Otherwise, offset the displays in System Settings.
- The relocation button may move the pointer for up to about 1.8 seconds and then restore it. User mouse movement or a button press interrupts it. The app does not move the pointer automatically in the background.
- DockPin must remain running. macOS can still choose another Dock display after restarting the Dock, logging in, or changing displays. The app then reports that the Dock needs to be moved back.
- When only one display is present, or separate Spaces are disabled, the filter stops. Sleep and user-session changes pause it until the environment is checked again.
- Display UUIDs are provided by macOS. Displays with duplicate or unstable UUIDs may need to be selected again.
- Full-screen apps, Mission Control, hot corners, and later macOS releases may behave differently. See [validation details](docs/VALIDATION.md).

## Build and test

Install Apple's Command Line Tools or Xcode with a macOS 14+ SDK. No package manager or third-party runtime is required.

```sh
git clone https://github.com/RichardLoZC/DockPin.git
cd DockPin
./scripts/build.sh
./scripts/test.sh
```

The app is written to `outputs/DockPin.app`. Tests cover 34 geometry and pointer-takeover cases, build and signature verification, and diagnostics. Native event-tap lifecycle checks run only when the test process already has Accessibility access; their empty policy passes all input through. Tests do not move the pointer or disconnect displays.

To prepare the release ZIP and SHA-256 checksum:

```sh
./scripts/package.sh
```

For local diagnostics:

```sh
outputs/DockPin.app/Contents/MacOS/DockPin --diagnose
```

Diagnostics include display names, UUIDs, coordinates, and permission state. Review this output before sharing it. A command launched from a trusted terminal can inherit permissions, so its result does not prove that the standalone GUI app is authorized.

## Source layout

```text
Sources/       App, display discovery, event filtering, and pointer takeover
Tests/         Geometry, takeover, and native event-tap lifecycle checks
Resources/     Original icon and reproducible icon generator
scripts/       Build, test, and packaging commands
docs/          Validation scope and results
```

## License and acknowledgements

DockPin is released under the [MIT License](LICENSE). The event-filtering approach and Dock-window detection were informed by [Lockdock](https://github.com/mishamyrt/lockdock), also MIT licensed. Its copyright notice is preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

DockPin is independent of the commercial DockLock apps and includes none of their code or assets.
