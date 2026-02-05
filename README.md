# Tab Switcher

A Chrome extension + native macOS app that brings **macOS-style Cmd+Tab switching to Chrome tabs**.

## Features

- **Ctrl+Tab** to cycle through tabs in Most Recently Used (MRU) order
- **Visual tab switcher** with thumbnails, favicons, and titles
- Hold Ctrl and press Tab repeatedly to cycle, release Ctrl to switch
- Works exactly like macOS app switching (Cmd+Tab)

## Installation

### Chrome Extension
1. Open Chrome and go to `chrome://extensions`
2. Enable "Developer mode"
3. Click "Load unpacked" and select this folder

### Native Helper App (macOS only)
The native app is required to intercept Ctrl+Tab (which Chrome doesn't allow extensions to override).

```bash
cd native-host
./install.sh
```

Then grant Accessibility permissions:
1. Open **System Settings > Privacy & Security > Accessibility**
2. Click the **+** button
3. Navigate to `~/Applications/` and add **Tab Switcher.app**
4. Enable the toggle

## Usage

- **Ctrl+Tab** - Cycle forward through recently used tabs (with visual UI)
- **Ctrl+Shift+Tab** - Cycle backward
- **Alt+W** - Quick switch to last tab (no UI)
- **Alt+S** - Cycle backward (timer-based)
- **Alt+Shift+S** - Cycle forward (timer-based)

## How It Works

1. The native macOS app intercepts Ctrl+Tab globally when Chrome is focused
2. It communicates with the Chrome extension via Native Messaging
3. The extension tracks tab order and provides thumbnails
4. A native SwiftUI window shows the visual tab switcher
5. Releasing Ctrl commits the selection and updates the MRU order

## Requirements

- macOS 11.0 or later
- Chrome browser
- Accessibility permissions for the native helper app

## License

MIT License - see [LICENSE](LICENSE)
