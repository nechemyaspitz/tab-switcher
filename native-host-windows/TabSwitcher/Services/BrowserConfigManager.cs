using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.Win32;
using TabSwitcher.Helpers;
using TabSwitcher.Models;

namespace TabSwitcher.Services
{
    /// <summary>
    /// Browser configuration manager.
    /// Port of BrowserConfigManager (main.swift:263-476).
    /// Handles config persistence, native messaging manifest/registry management, and remote browser list fetching.
    /// </summary>
    public class BrowserConfigManager : INotifyPropertyChanged
    {
        public static BrowserConfigManager Instance { get; } = new();

        private static readonly HttpClient _http = new();
        private static readonly JsonSerializerOptions _jsonOptions = new()
        {
            WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        private List<BrowserInfo> _browsers = new();
        private ShortcutsConfiguration _shortcuts = ShortcutsConfiguration.Defaults;
        private bool _showingSetup;

        public List<BrowserInfo> Browsers
        {
            get => _browsers;
            set { _browsers = value; OnPropertyChanged(); OnPropertyChanged(nameof(InstalledBrowsers)); }
        }

        public ShortcutsConfiguration Shortcuts
        {
            get => _shortcuts;
            set { _shortcuts = value; OnPropertyChanged(); }
        }

        public bool ShowingSetup
        {
            get => _showingSetup;
            set { _showingSetup = value; OnPropertyChanged(); }
        }

        public IEnumerable<BrowserInfo> InstalledBrowsers => Browsers.Where(b => b.IsInstalled);

        public HashSet<string> EnabledBrowserIds =>
            new(Browsers.Where(b => b.IsEnabled).Select(b => b.Id));

        // ---- Hardcoded fallback browser list for Windows ----
        private static readonly List<BrowserInfo> KnownBrowsers = new()
        {
            new() { Id = "com.google.Chrome", Name = "Google Chrome", AppName = "Google Chrome",
                     ExeName = "chrome.exe", RegistryKey = @"SOFTWARE\Google\Chrome\NativeMessagingHosts",
                     InstallPaths = new() { @"%PROGRAMFILES%\Google\Chrome\Application\chrome.exe", @"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" } },
            new() { Id = "com.brave.Browser", Name = "Brave", AppName = "Brave Browser",
                     ExeName = "brave.exe", RegistryKey = @"SOFTWARE\BraveSoftware\Brave-Browser\NativeMessagingHosts",
                     InstallPaths = new() { @"%PROGRAMFILES%\BraveSoftware\Brave-Browser\Application\brave.exe", @"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe" } },
            new() { Id = "com.microsoft.edgemac", Name = "Microsoft Edge", AppName = "Microsoft Edge",
                     ExeName = "msedge.exe", RegistryKey = @"SOFTWARE\Microsoft\Edge\NativeMessagingHosts",
                     InstallPaths = new() { @"%PROGRAMFILES(X86)%\Microsoft\Edge\Application\msedge.exe", @"%PROGRAMFILES%\Microsoft\Edge\Application\msedge.exe" } },
            new() { Id = "com.vivaldi.Vivaldi", Name = "Vivaldi", AppName = "Vivaldi",
                     ExeName = "vivaldi.exe", RegistryKey = @"SOFTWARE\Vivaldi\NativeMessagingHosts",
                     InstallPaths = new() { @"%LOCALAPPDATA%\Vivaldi\Application\vivaldi.exe" } },
            new() { Id = "com.operasoftware.Opera", Name = "Opera", AppName = "Opera",
                     ExeName = "opera.exe", RegistryKey = @"SOFTWARE\Google\Chrome\NativeMessagingHosts",
                     InstallPaths = new() { @"%LOCALAPPDATA%\Programs\Opera\opera.exe" } },
            new() { Id = "com.operasoftware.OperaGX", Name = "Opera GX", AppName = "Opera GX",
                     ExeName = "opera.exe", RegistryKey = @"SOFTWARE\Google\Chrome\NativeMessagingHosts",
                     InstallPaths = new() { @"%LOCALAPPDATA%\Programs\Opera GX\opera.exe" } },
            new() { Id = "org.chromium.Chromium", Name = "Chromium", AppName = "Chromium",
                     ExeName = "chrome.exe", RegistryKey = @"SOFTWARE\Chromium\NativeMessagingHosts",
                     InstallPaths = new() { @"%LOCALAPPDATA%\Chromium\Application\chrome.exe" } },
            new() { Id = "org.chromium.Thorium", Name = "Thorium", AppName = "Thorium",
                     ExeName = "thorium.exe", RegistryKey = @"SOFTWARE\Thorium\NativeMessagingHosts",
                     InstallPaths = new() { @"%PROGRAMFILES%\Thorium\Application\thorium.exe" } },
        };

        // ---- Config Loading ----

        public void LoadConfig()
        {
            var baseBrowsers = BaseBrowserList();

            // Try to load saved user config
            if (File.Exists(Constants.BrowserConfigPath))
            {
                try
                {
                    var json = File.ReadAllText(Constants.BrowserConfigPath);
                    var saved = JsonSerializer.Deserialize<List<BrowserInfo>>(json, _jsonOptions);
                    if (saved != null)
                    {
                        // Merge saved config into base list
                        foreach (var browser in baseBrowsers)
                        {
                            var savedBrowser = saved.FirstOrDefault(s => s.Id == browser.Id);
                            if (savedBrowser != null)
                            {
                                browser.ExtensionId = savedBrowser.ExtensionId;
                                browser.IsEnabled = savedBrowser.IsEnabled;
                                browser.CombineAllWindows = savedBrowser.CombineAllWindows;
                            }
                        }

                        // Keep any saved browsers not in base list
                        foreach (var savedBrowser in saved.Where(s => s.IsEnabled))
                        {
                            if (!baseBrowsers.Any(b => b.Id == savedBrowser.Id))
                                baseBrowsers.Add(savedBrowser);
                        }
                    }
                }
                catch (Exception ex)
                {
                    DebugLogger.Log($"Failed to load browser config: {ex.Message}");
                }
            }

            Browsers = baseBrowsers;
        }

        private List<BrowserInfo> BaseBrowserList()
        {
            // Try cached remote list first
            if (File.Exists(Constants.BrowserListCachePath))
            {
                try
                {
                    var json = File.ReadAllText(Constants.BrowserListCachePath);
                    var definitions = JsonSerializer.Deserialize<List<BrowserDefinition>>(json, _jsonOptions);
                    if (definitions != null && definitions.Count > 0)
                    {
                        DebugLogger.Log($"Using cached remote browser list ({definitions.Count} browsers)");
                        return definitions.Select(BrowserInfo.FromDefinition).ToList();
                    }
                }
                catch { }
            }

            DebugLogger.Log($"Using hardcoded browser list ({KnownBrowsers.Count} browsers)");
            return KnownBrowsers.Select(b => new BrowserInfo
            {
                Id = b.Id, Name = b.Name, AppName = b.AppName, ExeName = b.ExeName,
                RegistryKey = b.RegistryKey, InstallPaths = new(b.InstallPaths)
            }).ToList();
        }

        public void SaveConfig()
        {
            try
            {
                var json = JsonSerializer.Serialize(Browsers, _jsonOptions);
                File.WriteAllText(Constants.BrowserConfigPath, json);
                UpdateManifests();
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"Failed to save browser config: {ex.Message}");
            }
        }

        // ---- Shortcuts ----

        public void LoadShortcuts()
        {
            if (File.Exists(Constants.ShortcutsPath))
            {
                try
                {
                    var json = File.ReadAllText(Constants.ShortcutsPath);
                    var loaded = JsonSerializer.Deserialize<ShortcutsConfiguration>(json, _jsonOptions);
                    if (loaded != null)
                        Shortcuts = loaded;
                }
                catch (Exception ex)
                {
                    DebugLogger.Log($"Failed to load shortcuts: {ex.Message}");
                }
            }
        }

        public void SaveShortcuts()
        {
            try
            {
                var json = JsonSerializer.Serialize(Shortcuts, _jsonOptions);
                File.WriteAllText(Constants.ShortcutsPath, json);
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"Failed to save shortcuts: {ex.Message}");
            }
        }

        // ---- Browser Management ----

        public void EnableBrowser(string id, string extensionId)
        {
            var browser = Browsers.FirstOrDefault(b => b.Id == id);
            if (browser != null)
            {
                browser.ExtensionId = extensionId;
                browser.IsEnabled = true;
                SaveConfig();
                OnPropertyChanged(nameof(Browsers));
            }
        }

        public void DisableBrowser(string id)
        {
            var browser = Browsers.FirstOrDefault(b => b.Id == id);
            if (browser != null)
            {
                browser.IsEnabled = false;
                SaveConfig();
                OnPropertyChanged(nameof(Browsers));
            }
        }

        public void SetCombineWindows(string id, bool combine)
        {
            var browser = Browsers.FirstOrDefault(b => b.Id == id);
            if (browser != null)
            {
                browser.CombineAllWindows = combine;
                SaveConfig();
            }
        }

        // ---- Native Messaging Registration (Windows Registry) ----

        /// <summary>
        /// Update native messaging host manifests and registry entries.
        /// Port of updateManifests (main.swift:429-467).
        /// On Windows, this writes registry keys + JSON manifest files instead of macOS filesystem manifests.
        /// </summary>
        public void UpdateManifests()
        {
            var exePath = System.Reflection.Assembly.GetExecutingAssembly().Location;
            // For single-file published apps, use the process path
            if (string.IsNullOrEmpty(exePath) || exePath.EndsWith(".dll"))
            {
                exePath = Environment.ProcessPath ?? exePath;
            }
            DebugLogger.Log($"Using exe path for manifest: {exePath}");

            foreach (var browser in Browsers)
            {
                var registryKeyPath = $@"{browser.RegistryKey}\{Constants.NativeMessagingHostName}";

                if (browser.IsEnabled && !string.IsNullOrEmpty(browser.ExtensionId))
                {
                    // Create manifest JSON file in AppData
                    var manifestDir = Path.Combine(Constants.AppDataDir, "manifests");
                    Directory.CreateDirectory(manifestDir);
                    var manifestPath = Path.Combine(manifestDir, Constants.ManifestFileName);

                    var manifest = new
                    {
                        name = Constants.NativeMessagingHostName,
                        description = "Tab Switcher Native Helper",
                        path = exePath,
                        type = "stdio",
                        allowed_origins = new[] { $"chrome-extension://{browser.ExtensionId}/" }
                    };

                    var manifestJson = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });
                    File.WriteAllText(manifestPath, manifestJson);
                    DebugLogger.Log($"Created manifest for {browser.Name} at {manifestPath}");

                    // Write registry key pointing to manifest
                    try
                    {
                        using var key = Registry.CurrentUser.CreateSubKey(registryKeyPath);
                        key?.SetValue(null, manifestPath); // Default value = path to manifest
                        DebugLogger.Log($"Created registry key for {browser.Name}: HKCU\\{registryKeyPath}");
                    }
                    catch (Exception ex)
                    {
                        DebugLogger.Log($"Failed to write registry for {browser.Name}: {ex.Message}");
                    }
                }
                else
                {
                    // Remove registry key if disabled
                    try
                    {
                        Registry.CurrentUser.DeleteSubKey(registryKeyPath, throwOnMissingSubKey: false);
                    }
                    catch { }
                }
            }
        }

        // ---- Remote Browser List ----

        public async Task FetchRemoteBrowserListAsync()
        {
            try
            {
                var json = await _http.GetStringAsync(Constants.BrowserListUrl);
                var definitions = JsonSerializer.Deserialize<List<BrowserDefinition>>(json, _jsonOptions);
                if (definitions != null && definitions.Count > 0)
                {
                    File.WriteAllText(Constants.BrowserListCachePath, json);
                    DebugLogger.Log($"Cached remote browser list ({definitions.Count} browsers)");
                    LoadConfig(); // Reload to pick up new browsers
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"Failed to fetch remote browser list: {ex.Message}");
            }
        }

        // ---- INotifyPropertyChanged ----

        public event PropertyChangedEventHandler? PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
