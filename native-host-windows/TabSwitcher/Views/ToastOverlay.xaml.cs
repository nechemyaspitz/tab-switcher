using System;
using System.Windows;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using TabSwitcher.Helpers;

namespace TabSwitcher.Views
{
    /// <summary>
    /// Toast notification overlay.
    /// Port of ToastManager (main.swift:1324-1358) and ToastWindow (main.swift:1401-1425).
    /// </summary>
    public partial class ToastOverlay : Window
    {
        private DispatcherTimer? _dismissTimer;

        public ToastOverlay()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Show a toast message. Port of ToastManager.showToast (main.swift:1335-1357).
        /// </summary>
        public void ShowToast(string message, string detail, double durationSeconds = 2.0)
        {
            _dismissTimer?.Stop();

            MessageText.Text = message;
            DetailText.Text = detail;

            // Position at bottom-center of browser window
            PositionOverBrowser();

            // Fade in
            ToastBorder.Opacity = 1;
            Show();

            // Auto-dismiss
            _dismissTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(durationSeconds) };
            _dismissTimer.Tick += (s, e) =>
            {
                _dismissTimer?.Stop();
                // Fade out
                var fadeOut = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(250));
                fadeOut.Completed += (s2, e2) => Hide();
                ToastBorder.BeginAnimation(OpacityProperty, fadeOut);
            };
            _dismissTimer.Start();
        }

        private void PositionOverBrowser()
        {
            IntPtr hwnd = NativeMethods.GetForegroundWindow();
            if (hwnd != IntPtr.Zero && NativeMethods.GetWindowRect(hwnd, out var rect))
            {
                Left = rect.Left + (rect.Width - Width) / 2;
                Top = rect.Bottom - Height - 20;
            }
            else
            {
                var screen = SystemParameters.WorkArea;
                Left = screen.Left + (screen.Width - Width) / 2;
                Top = screen.Bottom - Height - 20;
            }
        }
    }
}
