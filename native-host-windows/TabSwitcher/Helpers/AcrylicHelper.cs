using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using TabSwitcher.Helpers;

namespace TabSwitcher.Helpers
{
    /// <summary>
    /// Applies acrylic/blur effects to WPF windows.
    /// Win10: SetWindowCompositionAttribute with ACCENT_ENABLE_ACRYLICBLURBEHIND
    /// Win11: DwmSetWindowAttribute with DWMWA_SYSTEMBACKDROP_TYPE
    /// Fallback: semi-transparent dark background
    /// </summary>
    public static class AcrylicHelper
    {
        public static void EnableBlur(Window window)
        {
            var hwnd = new WindowInteropHelper(window).Handle;
            if (hwnd == IntPtr.Zero) return;

            // Try Win11 Mica/Acrylic first
            if (TryWin11Backdrop(hwnd)) return;

            // Try Win10 Acrylic
            if (TryWin10Acrylic(hwnd)) return;

            // Fallback handled by XAML background
            DebugLogger.Log("Acrylic blur not available, using fallback background");
        }

        private static bool TryWin11Backdrop(IntPtr hwnd)
        {
            try
            {
                // Enable dark mode for proper acrylic appearance
                int darkMode = 1;
                NativeMethods.DwmSetWindowAttribute(hwnd, NativeMethods.DWMWA_USE_IMMERSIVE_DARK_MODE,
                    ref darkMode, sizeof(int));

                // Set Acrylic backdrop (value 3 = Acrylic, 2 = Mica, 4 = Mica Alt)
                int backdropType = 3;
                int result = NativeMethods.DwmSetWindowAttribute(hwnd, NativeMethods.DWMWA_SYSTEMBACKDROP_TYPE,
                    ref backdropType, sizeof(int));

                if (result == 0)
                {
                    DebugLogger.Log("Win11 acrylic backdrop enabled");
                    return true;
                }
            }
            catch { }

            return false;
        }

        private static bool TryWin10Acrylic(IntPtr hwnd)
        {
            try
            {
                var accent = new NativeMethods.AccentPolicy
                {
                    AccentState = NativeMethods.AccentState.ACCENT_ENABLE_ACRYLICBLURBEHIND,
                    GradientColor = 0x99000000 // Semi-transparent black (ABGR)
                };

                int accentSize = Marshal.SizeOf(accent);
                IntPtr accentPtr = Marshal.AllocHGlobal(accentSize);
                try
                {
                    Marshal.StructureToPtr(accent, accentPtr, false);

                    var data = new NativeMethods.WindowCompositionAttributeData
                    {
                        Attribute = NativeMethods.WindowCompositionAttribute.WCA_ACCENT_POLICY,
                        Data = accentPtr,
                        SizeOfData = accentSize
                    };

                    NativeMethods.SetWindowCompositionAttribute(hwnd, ref data);
                    DebugLogger.Log("Win10 acrylic blur enabled");
                    return true;
                }
                finally
                {
                    Marshal.FreeHGlobal(accentPtr);
                }
            }
            catch { }

            return false;
        }
    }
}
