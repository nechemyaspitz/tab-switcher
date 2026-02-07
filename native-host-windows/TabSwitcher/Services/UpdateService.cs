using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Windows.Threading;
using TabSwitcher.Helpers;

namespace TabSwitcher.Services
{
    /// <summary>
    /// Background update checker.
    /// Port of BackgroundUpdateChecker (main.swift:507-821).
    /// Checks version.json periodically and shows Windows toast notifications for updates.
    /// </summary>
    public class UpdateService
    {
        private static readonly HttpClient _http = new();
        private readonly bool _launchedDirectly;
        private Mutex? _updateMutex;
        private bool _isUpdateLeader;
        private DispatcherTimer? _checkTimer;
        private string? _connectedExtensionVersion;

        public UpdateService(bool launchedDirectly)
        {
            _launchedDirectly = launchedDirectly;
        }

        public void Start()
        {
            // Leader election for update checking (only one instance checks)
            try
            {
                _updateMutex = new Mutex(false, Constants.UpdateCheckerMutexName, out bool created);
                _isUpdateLeader = created || _updateMutex.WaitOne(0);
            }
            catch (AbandonedMutexException)
            {
                _isUpdateLeader = true;
            }
            catch
            {
                _isUpdateLeader = false;
            }

            if (!_isUpdateLeader)
            {
                DebugLogger.Log("Not the update check leader, skipping periodic checks");
                return;
            }

            DebugLogger.Log("We are the update check leader");

            // First check after 30 seconds
            var initialTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
            initialTimer.Tick += (s, e) =>
            {
                initialTimer.Stop();
                CheckForUpdates();
            };
            initialTimer.Start();

            // Then every 4 hours
            _checkTimer = new DispatcherTimer { Interval = TimeSpan.FromHours(4) };
            _checkTimer.Tick += (s, e) => CheckForUpdates();
            _checkTimer.Start();
        }

        public void SetExtensionVersion(string version)
        {
            _connectedExtensionVersion = version;
        }

        private async void CheckForUpdates()
        {
            if (!_isUpdateLeader) return;

            try
            {
                var json = await _http.GetStringAsync(Constants.VersionCheckUrl);
                var info = JsonSerializer.Deserialize<VersionInfo>(json);
                if (info != null)
                    ProcessVersionInfo(info);
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"Version check failed: {ex.Message}");
            }
        }

        /// <summary>
        /// Process version info. Port of processVersionInfo (main.swift:673-691).
        /// </summary>
        private void ProcessVersionInfo(VersionInfo info)
        {
            var notified = LoadNotifiedVersions();

            // Check app version
            if (IsNewerVersion(info.App.Version, Constants.AppVersion))
            {
                if (notified.App != info.App.Version)
                {
                    DebugLogger.Log($"App update available: {info.App.Version} (current: {Constants.AppVersion})");
                    // On Windows we don't have system toast notifications easily — log it for now
                    // NetSparkle handles the actual update UI
                    SaveNotifiedVersions(new NotifiedVersions { App = info.App.Version, Ext = notified.Ext });
                }
            }

            // Check extension version
            if (_connectedExtensionVersion != null &&
                IsNewerVersion(info.Extension.Version, _connectedExtensionVersion))
            {
                if (notified.Ext != info.Extension.Version)
                {
                    DebugLogger.Log($"Extension update available: {info.Extension.Version} (current: {_connectedExtensionVersion})");
                    SaveNotifiedVersions(new NotifiedVersions { App = notified.App, Ext = info.Extension.Version });
                }
            }
        }

        /// <summary>
        /// Semantic version comparison. Port of isNewerVersion (main.swift:694-704).
        /// </summary>
        private static bool IsNewerVersion(string remote, string local)
        {
            var remoteParts = remote.Split('.').Select(int.Parse).ToArray();
            var localParts = local.Split('.').Select(int.Parse).ToArray();
            int len = Math.Max(remoteParts.Length, localParts.Length);

            for (int i = 0; i < len; i++)
            {
                int r = i < remoteParts.Length ? remoteParts[i] : 0;
                int l = i < localParts.Length ? localParts[i] : 0;
                if (r > l) return true;
                if (r < l) return false;
            }
            return false;
        }

        // ---- Persistence ----

        private NotifiedVersions LoadNotifiedVersions()
        {
            try
            {
                if (File.Exists(Constants.NotifiedVersionsPath))
                {
                    var json = File.ReadAllText(Constants.NotifiedVersionsPath);
                    return JsonSerializer.Deserialize<NotifiedVersions>(json) ?? new NotifiedVersions();
                }
            }
            catch { }
            return new NotifiedVersions();
        }

        private void SaveNotifiedVersions(NotifiedVersions versions)
        {
            try
            {
                var json = JsonSerializer.Serialize(versions);
                File.WriteAllText(Constants.NotifiedVersionsPath, json);
            }
            catch { }
        }
    }

    // ---- DTOs ----

    public class VersionInfo
    {
        [JsonPropertyName("app")]
        public AppVersionInfo App { get; set; } = new();

        [JsonPropertyName("extension")]
        public ExtVersionInfo Extension { get; set; } = new();
    }

    public class AppVersionInfo
    {
        [JsonPropertyName("version")]
        public string Version { get; set; } = "";

        [JsonPropertyName("downloadUrl")]
        public string DownloadUrl { get; set; } = "";

        [JsonPropertyName("releaseNotes")]
        public string ReleaseNotes { get; set; } = "";
    }

    public class ExtVersionInfo
    {
        [JsonPropertyName("version")]
        public string Version { get; set; } = "";

        [JsonPropertyName("chromeWebStoreUrl")]
        public string? ChromeWebStoreUrl { get; set; }

        [JsonPropertyName("releaseNotes")]
        public string ReleaseNotes { get; set; } = "";
    }

    public class NotifiedVersions
    {
        [JsonPropertyName("app")]
        public string? App { get; set; }

        [JsonPropertyName("ext")]
        public string? Ext { get; set; }
    }
}
