using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Media.Imaging;
using TabSwitcher.Helpers;
using TabSwitcher.Models;
using TabSwitcher.NativeMessaging;

namespace TabSwitcher.Views
{
    /// <summary>
    /// Floating overlay window for tab switcher UI.
    /// Port of TabSwitcherWindow (main.swift:1682-1704) and TabSwitcherView (main.swift:1536-1573).
    /// Uses WindowStyle=None, AllowsTransparency, Topmost — must NOT steal focus from browser.
    /// </summary>
    public partial class TabSwitcherOverlay : Window
    {
        private ObservableCollection<TabViewModel> _tabs = new();

        public TabSwitcherOverlay()
        {
            InitializeComponent();
            TabCards.ItemsSource = _tabs;
        }

        /// <summary>
        /// Show the switcher overlay with tabs.
        /// Port of TabSwitcherState.showSwitcher (main.swift:1301-1306) and
        /// AppDelegate visibility observer (main.swift:1800-1858).
        /// </summary>
        public void ShowSwitcher(NativeMessage message)
        {
            if (message.Tabs == null || message.Tabs.Length == 0) return;

            _tabs.Clear();
            for (int i = 0; i < message.Tabs.Length; i++)
            {
                _tabs.Add(new TabViewModel(message.Tabs[i], i == message.SelectedIndex));
            }

            PositionAndSize(message.Tabs.Length);
            Show();
            DebugLogger.Log($"Showing switcher with {message.Tabs.Length} tabs");
        }

        public void UpdateSelection(int selectedIndex)
        {
            for (int i = 0; i < _tabs.Count; i++)
            {
                _tabs[i].IsSelected = (i == selectedIndex);
            }

            // Scroll to selected
            if (selectedIndex >= 0 && selectedIndex < _tabs.Count)
            {
                // Find the visual element and bring it into view
                var container = TabCards.ItemContainerGenerator.ContainerFromIndex(selectedIndex) as FrameworkElement;
                container?.BringIntoView();
            }
        }

        public void HideSwitcher()
        {
            Hide();
            _tabs.Clear();
            DebugLogger.Log("Hiding switcher");
        }

        /// <summary>
        /// Position and size the overlay, centered on the browser window.
        /// Port of AppDelegate positioning logic (main.swift:1806-1852).
        /// Uses GetWindowRect instead of AXUIElement.
        /// </summary>
        private void PositionAndSize(int tabCount)
        {
            double cardWidth = Constants.CardWidth;
            double cardSpacing = Constants.CardSpacing;
            double padding = Constants.OverlayPadding;
            double cardHeight = Constants.CardHeight;

            double contentWidth = tabCount * cardWidth + Math.Max(0, tabCount - 1) * cardSpacing + padding * 2;
            double height = cardHeight + padding * 2;

            // Get browser window rect
            var browserRect = GetBrowserWindowRect();
            double targetX, targetY, targetW, targetH;

            if (browserRect.HasValue)
            {
                targetX = browserRect.Value.Left;
                targetY = browserRect.Value.Top;
                targetW = browserRect.Value.Width;
                targetH = browserRect.Value.Height;
                DebugLogger.Log($"Using browser window rect: {targetX},{targetY} {targetW}x{targetH}");
            }
            else
            {
                var screen = SystemParameters.WorkArea;
                targetX = screen.Left;
                targetY = screen.Top;
                targetW = screen.Width;
                targetH = screen.Height;
                DebugLogger.Log($"Falling back to screen: {targetW}x{targetH}");
            }

            double maxWidth = Math.Min(targetW - 40, Constants.MaxOverlayWidth);
            double width = Math.Min(contentWidth, maxWidth);

            Width = width;
            Height = height;
            Left = targetX + (targetW - width) / 2;
            Top = targetY + (targetH - height) / 2 - targetH * 0.08; // Slightly above center
        }

        /// <summary>
        /// Get the foreground browser window rectangle.
        /// Port of getBrowserWindowFrame (main.swift:1597-1678).
        /// Uses GetForegroundWindow + GetWindowRect (much simpler than macOS AXUIElement).
        /// </summary>
        private NativeMethods.RECT? GetBrowserWindowRect()
        {
            IntPtr hwnd = NativeMethods.GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return null;

            if (NativeMethods.GetWindowRect(hwnd, out var rect))
            {
                if (rect.Width > 100 && rect.Height > 100)
                    return rect;
            }

            return null;
        }
    }

    // ---- View Model ----

    public class TabViewModel : INotifyPropertyChanged
    {
        private bool _isSelected;

        public int Id { get; set; }
        public string Title { get; set; } = "";
        public string FavIconUrl { get; set; } = "";
        public BitmapImage? Thumbnail { get; set; }
        public string Url { get; set; } = "";

        public bool IsSelected
        {
            get => _isSelected;
            set { _isSelected = value; PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsSelected))); }
        }

        public TabViewModel(TabInfo tab, bool isSelected)
        {
            Id = tab.Id;
            Title = tab.Title;
            FavIconUrl = tab.FavIconUrl;
            Thumbnail = tab.Thumbnail;
            Url = tab.Url;
            _isSelected = isSelected;
        }

        public event PropertyChangedEventHandler? PropertyChanged;
    }

}
