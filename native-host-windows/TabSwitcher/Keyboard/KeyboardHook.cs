using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Threading;
using TabSwitcher.Helpers;
using TabSwitcher.IPC;
using TabSwitcher.Models;
using TabSwitcher.Services;

namespace TabSwitcher.Keyboard
{
    /// <summary>
    /// Low-level keyboard hook for intercepting Ctrl+Tab and other shortcuts.
    /// Port of eventTapCallback (main.swift:2610-2711) and setupEventTap (main.swift:2715-2736).
    /// Uses SetWindowsHookEx(WH_KEYBOARD_LL) instead of CGEvent.tapCreate().
    /// </summary>
    public class KeyboardHook
    {
        private IntPtr _hookId = IntPtr.Zero;
        private NativeMethods.LowLevelKeyboardProc? _hookProc;
        private readonly InstanceCommunication _ipc;

        // State tracking (mirrors globals from main.swift:2199-2207)
        private bool _switchModifierIsPressed;
        private bool _switchInProgress;
        private int _tabPressCount;
        private DispatcherTimer? _showUITimer;

        public KeyboardHook(InstanceCommunication ipc)
        {
            _ipc = ipc;
        }

        public void Install()
        {
            _hookProc = HookCallback;
            using var process = Process.GetCurrentProcess();
            using var module = process.MainModule!;
            _hookId = NativeMethods.SetWindowsHookEx(
                NativeMethods.WH_KEYBOARD_LL,
                _hookProc,
                NativeMethods.GetModuleHandle(module.ModuleName!),
                0);

            if (_hookId == IntPtr.Zero)
            {
                DebugLogger.Log($"Failed to install keyboard hook: {Marshal.GetLastWin32Error()}");
            }
            else
            {
                DebugLogger.Log("Keyboard hook installed successfully");
            }
        }

        public void Uninstall()
        {
            if (_hookId != IntPtr.Zero)
            {
                NativeMethods.UnhookWindowsHookEx(_hookId);
                _hookId = IntPtr.Zero;
                DebugLogger.Log("Keyboard hook uninstalled");
            }
        }

        /// <summary>
        /// Low-level keyboard callback. Port of eventTapCallback (main.swift:2610-2711).
        /// </summary>
        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode < 0)
                return NativeMethods.CallNextHookEx(_hookId, nCode, wParam, lParam);

            var hookStruct = Marshal.PtrToStructure<NativeMethods.KBDLLHOOKSTRUCT>(lParam);
            int vkCode = (int)hookStruct.vkCode;
            int msg = (int)wParam;

            // Only process when a supported browser is in the foreground
            var frontmostBrowser = GetFrontmostBrowserId();
            if (frontmostBrowser == null)
                return NativeMethods.CallNextHookEx(_hookId, nCode, wParam, lParam);

            var shortcuts = BrowserConfigManager.Instance.Shortcuts;

            // Get current modifier state
            bool ctrlDown = (NativeMethods.GetAsyncKeyState(NativeMethods.VK_CONTROL) & 0x8000) != 0;
            bool shiftDown = (NativeMethods.GetAsyncKeyState(NativeMethods.VK_SHIFT) & 0x8000) != 0;
            bool altDown = (NativeMethods.GetAsyncKeyState(NativeMethods.VK_MENU) & 0x8000) != 0;

            var currentMods = ModifierKeysFlag.None;
            if (ctrlDown) currentMods |= ModifierKeysFlag.Control;
            if (shiftDown) currentMods |= ModifierKeysFlag.Shift;
            if (altDown) currentMods |= ModifierKeysFlag.Alt;

            // Determine the primary modifier for tab-switch (minus Shift, which toggles direction)
            var switchBaseMods = shortcuts.TabSwitch.Modifiers & ~ModifierKeysFlag.Shift;
            var currentBaseMods = currentMods & ~ModifierKeysFlag.Shift;

            // Handle key-up for modifier release detection
            if (msg == NativeMethods.WM_KEYUP || msg == NativeMethods.WM_SYSKEYUP)
            {
                // Check if this is the primary switch modifier being released
                bool isControlKey = vkCode == NativeMethods.VK_CONTROL ||
                                    vkCode == NativeMethods.VK_LCONTROL ||
                                    vkCode == NativeMethods.VK_RCONTROL;
                bool isAltKey = vkCode == NativeMethods.VK_MENU ||
                                vkCode == NativeMethods.VK_LMENU ||
                                vkCode == NativeMethods.VK_RMENU;

                bool switchModReleased = false;
                if (switchBaseMods.HasFlag(ModifierKeysFlag.Control) && isControlKey)
                    switchModReleased = true;
                if (switchBaseMods.HasFlag(ModifierKeysFlag.Alt) && isAltKey)
                    switchModReleased = true;

                if (switchModReleased && _switchModifierIsPressed && _switchInProgress)
                {
                    _showUITimer?.Stop();
                    _showUITimer = null;
                    _ipc.PostCtrlRelease(frontmostBrowser);
                    _switchInProgress = false;
                    _tabPressCount = 0;
                    _switchModifierIsPressed = false;
                }

                return NativeMethods.CallNextHookEx(_hookId, nCode, wParam, lParam);
            }

            // Handle key-down events
            if (msg == NativeMethods.WM_KEYDOWN || msg == NativeMethods.WM_SYSKEYDOWN)
            {
                // Check for tab-switch shortcut (Shift excluded from base match)
                if (vkCode == shortcuts.TabSwitch.VkCode && currentBaseMods == switchBaseMods && switchBaseMods != ModifierKeysFlag.None)
                {
                    if (!_switchInProgress)
                    {
                        _switchInProgress = true;
                        _tabPressCount = 0;
                    }
                    _switchModifierIsPressed = true;
                    _tabPressCount++;

                    var direction = shiftDown ? "cycle_prev" : "cycle_next";
                    bool combineWindows = false;

                    DebugLogger.Log($"Broadcasting tab switch: direction={direction}, tabPressCount={_tabPressCount}");

                    if (_tabPressCount == 1)
                    {
                        _ipc.PostCtrlTab(direction, showUI: false, combineWindows, frontmostBrowser);

                        // Schedule show UI after delay
                        _showUITimer?.Stop();
                        _showUITimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(Constants.ShowUIDelayMs) };
                        _showUITimer.Tick += (s, e) =>
                        {
                            _showUITimer?.Stop();
                            _ipc.PostRequestShowUI(combineWindows, frontmostBrowser);
                        };
                        _showUITimer.Start();
                    }
                    else
                    {
                        _showUITimer?.Stop();
                        _showUITimer = null;
                        _ipc.PostCtrlTab(direction, showUI: true, combineWindows, frontmostBrowser);
                    }

                    // Swallow the key (return non-zero to block)
                    return (IntPtr)1;
                }

                // Check for copy-URL shortcut
                if (vkCode == shortcuts.CopyUrl.VkCode && currentMods == shortcuts.CopyUrl.Modifiers && shortcuts.CopyUrl.Modifiers != ModifierKeysFlag.None)
                {
                    DebugLogger.Log("Copy URL shortcut detected");
                    _ipc.PostCopyUrl(frontmostBrowser);
                    return (IntPtr)1;
                }
            }

            return NativeMethods.CallNextHookEx(_hookId, nCode, wParam, lParam);
        }

        /// <summary>
        /// Get the frontmost browser's ID. Port of isSupportedBrowserActive (main.swift:2132-2149)
        /// and getFrontmostBrowserBundleId (main.swift:2536-2549).
        /// </summary>
        private string? GetFrontmostBrowserId()
        {
            IntPtr hwnd = NativeMethods.GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return null;

            NativeMethods.GetWindowThreadProcessId(hwnd, out uint processId);
            if (processId == 0) return null;

            try
            {
                using var process = Process.GetProcessById((int)processId);
                var processName = process.ProcessName.ToLowerInvariant();

                // Map process name to browser ID
                return processName switch
                {
                    "chrome" => "com.google.Chrome",
                    "brave" => "com.brave.Browser",
                    "msedge" => "com.microsoft.edgemac",
                    "vivaldi" => "com.vivaldi.Vivaldi",
                    "opera" => "com.operasoftware.Opera",
                    "thorium" => "org.chromium.Thorium",
                    _ => null
                };
            }
            catch
            {
                return null;
            }
        }
    }
}
