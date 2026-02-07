using System;
using System.IO;

namespace TabSwitcher
{
    public static class Constants
    {
        public const string AppVersion = "3.7.4";
        public const string AppName = "Tab Switcher";
        public const string NativeMessagingHostName = "com.tabswitcher.native";
        public const string ManifestFileName = "com.tabswitcher.native.json";

        // IPC
        public const string EventTapMutexName = "Global\\TabSwitcherEventTap";
        public const string UpdateCheckerMutexName = "Global\\TabSwitcherUpdateChecker";
        public const string IpcPipeName = "TabSwitcherIPC";

        // URLs
        public const string BrowserListUrl = "https://tabswitcher.app/browsers.json";
        public const string VersionCheckUrl = "https://tabswitcher.app/version.json";
        public const string AppcastUrl = "https://tabswitcher.app/appcast.xml";
        public const string ExtensionDownloadUrl = "https://github.com/nechemyaspitz/tab-switcher/archive/refs/heads/master.zip";

        // Paths
        public static readonly string AppDataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "TabSwitcher");

        public static readonly string BrowserConfigPath = Path.Combine(AppDataDir, "browser_config.json");
        public static readonly string BrowserListCachePath = Path.Combine(AppDataDir, "browser_list_cache.json");
        public static readonly string ShortcutsPath = Path.Combine(AppDataDir, "shortcuts.json");
        public static readonly string NotifiedVersionsPath = Path.Combine(AppDataDir, "notified_versions.json");

        public static readonly string DebugLogPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "tabswitcher_debug.log");

        // UI dimensions
        public const double CardWidth = 220;
        public const double CardHeight = 146;
        public const double CardCornerRadius = 10;
        public const double CardSpacing = 12;
        public const double OverlayPadding = 16;
        public const double OverlayCornerRadius = 20;
        public const double MaxOverlayWidth = 1200;
        public const double ShowUIDelayMs = 150;

        // Setup window
        public const double SetupWidth = 460;
        public const double SetupHeight = 580;

        public static void EnsureAppDataDir()
        {
            Directory.CreateDirectory(AppDataDir);
        }
    }
}
