using System.Collections.Generic;
using System.Text.Json.Serialization;
using TabSwitcher.Services;

namespace TabSwitcher.Models
{
    /// <summary>
    /// Browser definition fetched from remote browsers.json
    /// </summary>
    public class BrowserDefinition
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("appName")]
        public string AppName { get; set; } = "";

        [JsonPropertyName("nativeMessagingPath")]
        public string NativeMessagingPath { get; set; } = "";

        [JsonPropertyName("windows")]
        public WindowsBrowserInfo? Windows { get; set; }
    }

    public class WindowsBrowserInfo
    {
        [JsonPropertyName("exeName")]
        public string ExeName { get; set; } = "";

        [JsonPropertyName("registryKey")]
        public string RegistryKey { get; set; } = "";

        [JsonPropertyName("installPaths")]
        public List<string> InstallPaths { get; set; } = new();
    }

    /// <summary>
    /// User-facing browser configuration (persisted locally)
    /// </summary>
    public class BrowserInfo
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("appName")]
        public string AppName { get; set; } = "";

        [JsonPropertyName("exeName")]
        public string ExeName { get; set; } = "";

        [JsonPropertyName("registryKey")]
        public string RegistryKey { get; set; } = "";

        [JsonPropertyName("installPaths")]
        public List<string> InstallPaths { get; set; } = new();

        [JsonPropertyName("extensionId")]
        public string? ExtensionId { get; set; }

        [JsonPropertyName("isEnabled")]
        public bool IsEnabled { get; set; }

        [JsonPropertyName("combineAllWindows")]
        public bool CombineAllWindows { get; set; }

        [JsonIgnore]
        public bool IsInstalled => BrowserDetector.IsBrowserInstalled(this);

        [JsonIgnore]
        public string? InstalledPath => BrowserDetector.FindBrowserPath(this);

        public static BrowserInfo FromDefinition(BrowserDefinition def)
        {
            return new BrowserInfo
            {
                Id = def.Id,
                Name = def.Name,
                AppName = def.AppName,
                ExeName = def.Windows?.ExeName ?? GuessBrowserExeName(def.Id),
                RegistryKey = def.Windows?.RegistryKey ?? GuessBrowserRegistryKey(def.Id),
                InstallPaths = def.Windows?.InstallPaths ?? new List<string>(),
                IsEnabled = false,
                CombineAllWindows = false
            };
        }

        private static string GuessBrowserExeName(string id)
        {
            return id switch
            {
                "com.google.Chrome" => "chrome.exe",
                "com.google.Chrome.dev" => "chrome.exe",
                "com.google.Chrome.canary" => "chrome.exe",
                "com.brave.Browser" => "brave.exe",
                "com.microsoft.edgemac" => "msedge.exe",
                "com.vivaldi.Vivaldi" => "vivaldi.exe",
                "com.operasoftware.Opera" => "opera.exe",
                "com.operasoftware.OperaGX" => "opera.exe",
                "org.chromium.Chromium" => "chrome.exe",
                "org.chromium.Thorium" => "thorium.exe",
                _ => "chrome.exe"
            };
        }

        private static string GuessBrowserRegistryKey(string id)
        {
            return id switch
            {
                "com.google.Chrome" => @"SOFTWARE\Google\Chrome\NativeMessagingHosts",
                "com.google.Chrome.dev" => @"SOFTWARE\Google\Chrome Dev\NativeMessagingHosts",
                "com.google.Chrome.canary" => @"SOFTWARE\Google\Chrome SxS\NativeMessagingHosts",
                "com.brave.Browser" => @"SOFTWARE\BraveSoftware\Brave-Browser\NativeMessagingHosts",
                "com.microsoft.edgemac" => @"SOFTWARE\Microsoft\Edge\NativeMessagingHosts",
                "com.vivaldi.Vivaldi" => @"SOFTWARE\Vivaldi\NativeMessagingHosts",
                "com.operasoftware.Opera" => @"SOFTWARE\Google\Chrome\NativeMessagingHosts",
                "com.operasoftware.OperaGX" => @"SOFTWARE\Google\Chrome\NativeMessagingHosts",
                "org.chromium.Chromium" => @"SOFTWARE\Chromium\NativeMessagingHosts",
                "org.chromium.Thorium" => @"SOFTWARE\Thorium\NativeMessagingHosts",
                _ => @"SOFTWARE\Google\Chrome\NativeMessagingHosts"
            };
        }
    }
}
