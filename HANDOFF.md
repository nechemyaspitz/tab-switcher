# Tab Switcher - Project Handoff

## What This Project Is
A macOS-style Ctrl+Tab tab switcher for Chrome and Chromium browsers. It has two components:
1. **Chrome Extension** - Tracks tab MRU order, captures thumbnails, displays visual switcher
2. **Native macOS App** - Intercepts Ctrl+Tab globally, communicates with extension via Native Messaging

## Project Location
`/Users/nechemyaspitz/Documents/tab-switcher`

## GitHub Repo
https://github.com/nechemyaspitz/tab-switcher

## Website (GitHub Pages)
https://nechemyaspitz.github.io/tab-switcher/
- Landing page: `/docs/index.html`
- Setup guide: `/docs/setup.html` (opens on extension first install)
- Privacy policy: `/docs/privacy.html`

---

## What's Been Completed

### Extension
- ✅ Full MRU tab tracking
- ✅ Visual tab switcher with thumbnails, favicons, titles
- ✅ Native messaging integration
- ✅ Window-specific tab cycling (configurable per browser)
- ✅ Opens setup page on first install
- ✅ Ready for Chrome Web Store upload

### Native macOS App
- ✅ Global Ctrl+Tab interception via CGEventTap
- ✅ SwiftUI visual tab switcher overlay
- ✅ Multi-browser support (Chrome, Brave, Edge, Arc, Vivaldi, Opera, Helium, etc.)
- ✅ Configuration UI for enabling browsers
- ✅ "Cycle through all windows" toggle per browser
- ✅ Single-instance enforcement for config UI
- ✅ Accessibility permission prompt
- ✅ App binary at `/Applications/Tab Switcher.app`

### Deployment
- ✅ GitHub repo created and pushed
- ✅ GitHub Pages website live
- ✅ Extension ZIP ready: `/dist/tab-switcher-extension.zip`
- ✅ Privacy policy created

---

## What's Pending / Next Steps

### 1. Chrome Web Store Submission
- Upload `/dist/tab-switcher-extension.zip` to https://chrome.google.com/webstore/devconsole
- Need screenshots (1280x800 or 640x400)
- Privacy policy URL: https://nechemyaspitz.github.io/tab-switcher/privacy.html
- After approval, get the permanent extension ID

### 2. Sign & Notarize macOS App
User has Apple Developer account. Steps:
```bash
# Find signing identity
security find-identity -v -p codesigning

# Sign the app
codesign --deep --force --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  "/Applications/Tab Switcher.app"

# Create ZIP for notarization
ditto -c -k --keepParent "/Applications/Tab Switcher.app" "TabSwitcher.zip"

# Submit for notarization
xcrun notarytool submit "TabSwitcher.zip" \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password" \
  --wait

# Staple the ticket
xcrun stapler staple "/Applications/Tab Switcher.app"

# Create DMG for distribution
hdiutil create -volname "Tab Switcher" \
  -srcfolder "/Applications/Tab Switcher.app" \
  -ov -format UDZO "TabSwitcher.dmg"
```

### 3. After Chrome Web Store Approval
- Get the permanent extension ID from the Chrome Web Store dashboard
- Can hardcode this ID in the native app so users don't need to enter it manually
- Update website download links

### 4. Website Polish (Optional)
- Add actual download links (currently placeholder `#`)
- Add screenshots/demo GIF
- Consider custom domain (e.g., tabswitcher.app)

---

## Key Files

| File | Purpose |
|------|---------|
| `mainsw.js` | Extension service worker (all extension logic) |
| `manifest.json` | Extension manifest |
| `native-host/Sources/tab-switcher/main.swift` | Native macOS app (all Swift code) |
| `native-host/Package.swift` | Swift package manifest |
| `docs/` | Website files for GitHub Pages |
| `dist/tab-switcher-extension.zip` | Ready-to-upload Chrome Web Store ZIP |

---

## Technical Notes

### Extension ID Situation
- Currently using unpacked extension (ID varies per machine)
- Once on Chrome Web Store, everyone gets the same stable ID
- The native app currently requires users to enter extension ID manually
- After store approval, can hardcode the ID for easier setup

### Multi-Browser Support
The app supports: Chrome, Brave, Edge, Arc, Vivaldi, Opera, Opera GX, Chromium, Helium
Each browser needs the extension installed and enabled in the native app config.

### Window Cycling Option
Per-browser setting: "Cycle through all windows"
- OFF (default): Only shows tabs from the currently active window
- ON: Shows tabs from all windows of that browser

### Native Messaging
- Host ID: `com.tabswitcher.native`
- Manifests written to each browser's NativeMessagingHosts folder
- App binary path: `/Applications/Tab Switcher.app/Contents/MacOS/tab-switcher`

---

## Commands to Rebuild

```bash
# Rebuild native app
cd /Users/nechemyaspitz/Documents/tab-switcher/native-host
swift build -c release

# Copy to app bundle
cp .build/release/tab-switcher "/Applications/Tab Switcher.app/Contents/MacOS/tab-switcher"
cp .build/release/tab-switcher "/Applications/Tab Switcher.app/Contents/MacOS/Tab Switcher"

# Rebuild extension ZIP
cd /Users/nechemyaspitz/Documents/tab-switcher
zip -r dist/tab-switcher-extension.zip manifest.json mainsw.js icon16.png icon32.png icon48.png icon128.png
```

---

*Last updated: February 5, 2026*
