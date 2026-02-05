# Tab Switcher

**Ctrl+Tab, reimagined.** Switch between browser tabs the way you switch between apps — with visual previews and most-recently-used ordering.

[Website](https://tabswitcher.app) · [Download](https://tabswitcher.app/Tab%20Switcher.dmg) · [Setup Guide](https://tabswitcher.app/setup)

> **Note:** Tab Switcher is currently pending Chrome Web Store approval. For now, manual installation is required. Once approved, you'll be able to install directly from the Chrome Web Store without needing to enter an Extension ID.

## Features

- **Visual tab previews** — See thumbnails, favicons, and titles as you cycle through tabs
- **Most recently used order** — Tabs ordered by recency, not position. One Ctrl+Tab instantly jumps to your last tab
- **Native performance** — A lightweight macOS companion app intercepts the shortcut at the system level
- **Multi-browser support** — Chrome, Brave, Edge, Arc, Vivaldi, Opera, and any Chromium-based browser

## How It Works

Hold **Ctrl** and press **Tab** to bring up the visual switcher. Keep holding Ctrl and press Tab repeatedly to cycle through your tabs. Release Ctrl to switch to the selected tab.

Works exactly like macOS app switching (Cmd+Tab), but for your browser tabs.

## Installation

Tab Switcher requires two components: a browser extension and a native macOS app.

### 1. Install the Extension (Manual — Chrome Web Store coming soon)

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

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable the toggle next to Tab Switcher

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Ctrl+Tab** | Open switcher, cycle forward |
| **Ctrl+Shift+Tab** | Cycle backward |
| **Alt+W** | Quick switch to last tab (no UI) |

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

The app bundle is at `dist/Tab Switcher.app`.

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
