using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32;
using TabSwitcher.Helpers;
using TabSwitcher.Models;

namespace TabSwitcher.Services
{
    /// <summary>
    /// Detects installed browsers and parent browser process.
    /// Port of detectParentBrowser (main.swift:2211-2284) and BrowserInfo.isInstalled (main.swift:192-199).
    /// </summary>
    public static class BrowserDetector
    {
        private static readonly Dictionary<string, string> ProcessNameToBrowserId = new(StringComparer.OrdinalIgnoreCase)
        {
            ["chrome"] = "com.google.Chrome",
            ["brave"] = "com.brave.Browser",
            ["msedge"] = "com.microsoft.edgemac",
            ["vivaldi"] = "com.vivaldi.Vivaldi",
            ["opera"] = "com.operasoftware.Opera",
            ["thorium"] = "org.chromium.Thorium",
            ["chromium"] = "org.chromium.Chromium",
        };

        /// <summary>
        /// Check if a browser is installed by scanning known paths and registry.
        /// </summary>
        public static bool IsBrowserInstalled(BrowserInfo browser)
        {
            return FindBrowserPath(browser) != null;
        }

        /// <summary>
        /// Find the installed path of a browser.
        /// </summary>
        public static string? FindBrowserPath(BrowserInfo browser)
        {
            // Check explicit install paths
            foreach (var rawPath in browser.InstallPaths)
            {
                var path = Environment.ExpandEnvironmentVariables(rawPath);
                if (File.Exists(path))
                    return path;
            }

            // Check App Paths registry
            try
            {
                using var key = Registry.LocalMachine.OpenSubKey($@"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{browser.ExeName}");
                var defaultValue = key?.GetValue(null) as string;
                if (defaultValue != null && File.Exists(defaultValue))
                    return defaultValue;
            }
            catch { }

            // Check common installation directories
            var commonDirs = new[]
            {
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)),
            };

            foreach (var dir in commonDirs)
            {
                var searchPatterns = GetSearchPatterns(browser.Id);
                foreach (var pattern in searchPatterns)
                {
                    var fullPath = Path.Combine(dir, pattern);
                    if (File.Exists(fullPath))
                        return fullPath;
                }
            }

            return null;
        }

        private static string[] GetSearchPatterns(string browserId)
        {
            return browserId switch
            {
                "com.google.Chrome" => new[] {
                    @"Google\Chrome\Application\chrome.exe",
                    @"Google\Chrome\chrome.exe"
                },
                "com.google.Chrome.dev" => new[] {
                    @"Google\Chrome Dev\Application\chrome.exe"
                },
                "com.google.Chrome.canary" => new[] {
                    @"Google\Chrome SxS\Application\chrome.exe"
                },
                "com.brave.Browser" => new[] {
                    @"BraveSoftware\Brave-Browser\Application\brave.exe"
                },
                "com.microsoft.edgemac" => new[] {
                    @"Microsoft\Edge\Application\msedge.exe"
                },
                "com.vivaldi.Vivaldi" => new[] {
                    @"Vivaldi\Application\vivaldi.exe"
                },
                "com.operasoftware.Opera" => new[] {
                    @"Opera\opera.exe"
                },
                "com.operasoftware.OperaGX" => new[] {
                    @"Opera GX\opera.exe"
                },
                "org.chromium.Chromium" => new[] {
                    @"Chromium\Application\chrome.exe"
                },
                "org.chromium.Thorium" => new[] {
                    @"Thorium\Application\thorium.exe"
                },
                _ => Array.Empty<string>()
            };
        }

        /// <summary>
        /// Detect which browser launched this native host by walking the process tree.
        /// Port of detectParentBrowser (main.swift:2211-2284).
        /// Uses NtQueryInformationProcess to get parent PID (replaces sysctl).
        /// </summary>
        public static (string browserId, uint processId)? DetectParentBrowser()
        {
            try
            {
                int currentPid;
                using (var self = Process.GetCurrentProcess())
                {
                    currentPid = GetParentProcessId(self.Handle);
                }

                DebugLogger.Log($"Starting parent detection from PID: {currentPid}");

                for (int level = 0; level < 10; level++)
                {
                    if (currentPid <= 0) break;

                    try
                    {
                        using var proc = Process.GetProcessById(currentPid);
                        var processName = proc.ProcessName.ToLowerInvariant();

                        DebugLogger.Log($"Level {level}: PID {currentPid} = {processName}");

                        if (ProcessNameToBrowserId.TryGetValue(processName, out var browserId))
                        {
                            DebugLogger.Log($"Found browser at level {level}: {browserId} with PID {currentPid}");
                            return (browserId, (uint)currentPid);
                        }

                        // Walk up to parent
                        int parentPid = GetParentProcessId(proc.Handle);
                        if (parentPid == currentPid || parentPid <= 0)
                            break;

                        currentPid = parentPid;
                    }
                    catch
                    {
                        DebugLogger.Log($"Failed to get process info at level {level}");
                        break;
                    }
                }

                DebugLogger.Log("Could not detect parent browser after walking tree");
                return null;
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"Parent browser detection failed: {ex.Message}");
                return null;
            }
        }

        private static int GetParentProcessId(IntPtr processHandle)
        {
            var pbi = new NativeMethods.PROCESS_BASIC_INFORMATION();
            int status = NativeMethods.NtQueryInformationProcess(
                processHandle, 0, ref pbi,
                Marshal.SizeOf(pbi), out _);

            if (status == 0)
                return (int)pbi.InheritedFromUniqueProcessId;

            return -1;
        }
    }
}
