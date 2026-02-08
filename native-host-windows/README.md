# Tab Switcher — Windows

Windows port of Tab Switcher using C#/WPF/.NET 8.

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Windows 10 or later (x64)
- A Chromium browser (Chrome, Brave, Edge, Vivaldi)

## Build

```powershell
cd native-host-windows
.\build.ps1
```

This runs `dotnet publish` and produces a self-contained single-file exe at `dist\publish\TabSwitcher.exe`.

To build manually:

```powershell
dotnet publish TabSwitcher\TabSwitcher.csproj -c Release -r win-x64 --self-contained -o dist\publish /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true
```

## Install the Extension

1. Go to `chrome://extensions` in your browser
2. Enable **Developer mode** (toggle in top-right)
3. Click **Load unpacked** and select the `docs/` folder from this repo

## Register the Native Messaging Host

The app needs a JSON manifest and a registry entry so the browser can find it.

**Create the manifest** — save this as `com.tabswitcher.native.json` next to `TabSwitcher.exe`, replacing the path with your actual exe location:

```json
{
  "name": "com.tabswitcher.native",
  "description": "Tab Switcher Native Helper",
  "path": "C:\\path\\to\\TabSwitcher.exe",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://*/"]
}
```

**Add the registry entry** (run in PowerShell — pick the one for your browser):

```powershell
# Chrome
reg add "HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.tabswitcher.native" /ve /d "C:\path\to\com.tabswitcher.native.json" /f

# Brave
reg add "HKCU\SOFTWARE\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.tabswitcher.native" /ve /d "C:\path\to\com.tabswitcher.native.json" /f

# Edge
reg add "HKCU\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.tabswitcher.native" /ve /d "C:\path\to\com.tabswitcher.native.json" /f

# Vivaldi
reg add "HKCU\SOFTWARE\Vivaldi\NativeMessagingHosts\com.tabswitcher.native" /ve /d "C:\path\to\com.tabswitcher.native.json" /f
```

Alternatively, launch `TabSwitcher.exe` directly — the setup window lets you enable browsers and it writes the manifest + registry entries automatically.

## Run

- **Direct launch** — double-click `TabSwitcher.exe`. Opens the setup window where you can configure browsers and shortcuts.
- **Via browser** — once the native messaging host is registered, the extension will launch the app automatically when you open the browser. It runs in the background with no taskbar icon.

## Test It

1. Build the app and register the native messaging host (above)
2. Load the extension in your browser
3. Open a few tabs
4. Press **Ctrl+Tab** — the tab switcher overlay should appear
5. Release **Ctrl** to switch to the selected tab

## Debug Logs

Logs are written to `%USERPROFILE%\tabswitcher_debug.log`. Check this file if something isn't working.

## Project Structure

```
TabSwitcher/
├── App.xaml.cs                  # Entry point, launch mode detection
├── Constants.cs                 # Version, paths, config
├── Helpers/
│   ├── AcrylicHelper.cs         # Win10/11 blur effects
│   ├── DebugLogger.cs           # Logging
│   └── NativeMethods.cs         # P/Invoke declarations
├── Models/                      # Data models (TabInfo, ShortcutConfig, BrowserInfo)
├── NativeMessaging/
│   └── NativeMessagingHost.cs   # stdin/stdout protocol
├── Keyboard/
│   └── KeyboardHook.cs          # System-level Ctrl+Tab interception
├── IPC/
│   ├── LeaderElection.cs        # Mutex-based singleton
│   └── InstanceCommunication.cs # Named pipes between instances
├── Services/
│   ├── BrowserConfigManager.cs  # Config + manifest management
│   ├── BrowserDetector.cs       # Find installed browsers
│   └── UpdateService.cs         # Auto-update checker
└── Views/                       # WPF windows (overlay, setup, toast)
```
