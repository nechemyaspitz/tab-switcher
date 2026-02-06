# Tab Switcher

**Ctrl+Tab, reimagined.** Switch between browser tabs the way you switch between apps — with visual previews and most-recently-used ordering.

[Website](https://tabswitcher.app) · [Download](https://tabswitcher.app/Tab%20Switcher.dmg) · [Setup Guide](https://tabswitcher.app/setup)

## Features

- **Visual tab previews** — See thumbnails, favicons, and titles as you cycle through tabs
- **Most recently used order** — Tabs ordered by recency, not position. One Ctrl+Tab instantly jumps to your last tab
- **Copy URL shortcut** — Press Cmd+Shift+C to copy the current tab's URL to your clipboard with a confirmation toast
- **Customizable shortcuts** — Remap both the tab switcher and copy URL shortcuts to any key combination
- **Native performance** — A lightweight macOS companion app intercepts shortcuts at the system level
- **Multi-browser support** — Chrome, Brave, Edge, Arc, Vivaldi, Opera, and any Chromium-based browser
- **Auto-updates** — The native app updates itself automatically via Sparkle

## How It Works

Hold **Ctrl** and press **Tab** to bring up the visual switcher. Keep holding Ctrl and press Tab repeatedly to cycle through your tabs. Release Ctrl to switch to the selected tab.

Press **Cmd+Shift+C** to instantly copy the active tab's URL to your clipboard.

Works exactly like macOS app switching (Cmd+Tab), but for your browser tabs.

## Installation

Tab Switcher requires two components: a browser extension and a native macOS app.

### 1. Install the Extension

1. Download or clone this repository
2. Open Chrome and go to `chrome://extensions`
3. Enable **Developer mode** (toggle in top right)
4. Click **Load unpacked** and select this folder
5. Note the **Extension ID** shown (you'll need this later)

### 2. Install the Native App

Download the macOS app from [tabswitcher.app](https://tabswitcher.app/Tab%20Switcher.dmg).

1. Open the DMG and drag Tab Switcher to Applications
2. Open Tab Switcher from Applications
3. Grant Accessibility permission when prompted
4. Click **Enable** for your browser
5. Enter the **Extension ID** from step 1.5 and click **Save**

### 3. Grant Accessibility Permissions

If not prompted automatically:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Enable the toggle next to Tab Switcher

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Ctrl+Tab** | Open switcher, cycle forward |
| **Ctrl+Shift+Tab** | Cycle backward |
| **Cmd+Shift+C** | Copy current tab URL |
| **Alt+W** | Quick switch to last tab (no UI) |

All shortcuts can be customized in the app's setup window.

## Requirements

- macOS 14.0 or later
- Any Chromium-based browser (Chrome, Brave, Edge, Arc, Vivaldi, Opera, etc.)
- Accessibility permissions for the native app

## Privacy

Tab Switcher operates entirely locally. No data is collected, stored, or transmitted. See our [Privacy Policy](https://tabswitcher.app/privacy).

## Building from Source

### Extension
The extension files are in the root directory. Load unpacked in Chrome.

### Native App
```bash
cd native-host
swift build -c release
```

The built binary will be at `native-host/.build/release/tab-switcher`. To create a full app bundle with the Sparkle framework embedded:

```bash
cd native-host
./build.sh
```

The app bundle will be at `dist/Tab Switcher.app`. Code signing and notarization require a valid Apple Developer ID certificate and are optional for local development:

```bash
./build.sh --sign              # build + code sign
./build.sh --sign --notarize   # build + sign + notarize
```

## Project Structure

```
├── manifest.json          # Chrome extension manifest
├── mainsw.js              # Extension service worker
├── popup.html/js          # Extension popup UI
├── icon*.png              # Extension icons
├── native-host/
│   ├── Package.swift      # Swift package definition
│   ├── Sources/
│   │   └── tab-switcher/
│   │       └── main.swift # Native macOS app
│   ├── build.sh           # Build + sign + notarize script
│   ├── install.sh         # Install native messaging host
│   └── uninstall.sh       # Uninstall native messaging host
└── docs/                  # Website (GitHub Pages)
    ├── index.html
    ├── setup.html
    └── privacy.html
```

## Troubleshooting

**Extension shows "Not connected":**
- Make sure the Tab Switcher app is running
- Check that you've granted Accessibility permissions
- Verify the Extension ID was entered correctly

**Ctrl+Tab doesn't work:**
- Verify Accessibility permissions are enabled
- Make sure the browser window is focused

For more help, visit the [Setup Guide](https://tabswitcher.app/setup).

## License

MIT License — see [LICENSE](LICENSE)
