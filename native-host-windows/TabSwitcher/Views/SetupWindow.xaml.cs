using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using TabSwitcher.Helpers;
using TabSwitcher.Models;
using TabSwitcher.Services;

namespace TabSwitcher.Views
{
    /// <summary>
    /// Setup/configuration window.
    /// Port of SetupView (main.swift:929-1087) and BrowserRowView (main.swift:1091-1217).
    /// 460x580 window with browser list, shortcut config, version info.
    /// </summary>
    public partial class SetupWindow : Window
    {
        private readonly ObservableCollection<BrowserRowViewModel> _browserRows = new();
        private string _recordingShortcutTarget = "";
        private string _expandedBrowserId = "";
        private readonly Dictionary<string, string> _extensionIdInputs = new();

        public SetupWindow()
        {
            InitializeComponent();

            VersionText.Text = $"v{Constants.AppVersion}";
            BrowserList.ItemsSource = _browserRows;

            RefreshShortcutButtons();
            RefreshBrowserList();

            PreviewKeyDown += OnPreviewKeyDown;
        }

        private void RefreshBrowserList()
        {
            _browserRows.Clear();
            foreach (var browser in BrowserConfigManager.Instance.InstalledBrowsers)
            {
                _browserRows.Add(new BrowserRowViewModel(browser, browser.Id == _expandedBrowserId));
            }
        }

        private void RefreshShortcutButtons()
        {
            var shortcuts = BrowserConfigManager.Instance.Shortcuts;
            TabSwitchShortcut.Content = shortcuts.TabSwitch.DisplayString;
            CopyUrlShortcut.Content = shortcuts.CopyUrl.DisplayString;
        }

        // ---- Browser Row Events ----

        private void BrowserRow_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string id)
            {
                _expandedBrowserId = _expandedBrowserId == id ? "" : id;
                RefreshBrowserList();
            }
        }

        private void EnableBrowser_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string id)
            {
                if (_extensionIdInputs.TryGetValue(id, out var extId) && extId.Length == 32)
                {
                    BrowserConfigManager.Instance.EnableBrowser(id, extId);
                    RefreshBrowserList();
                }
            }
        }

        private void DisableBrowser_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string id)
            {
                BrowserConfigManager.Instance.DisableBrowser(id);
                RefreshBrowserList();
            }
        }

        private void CombineWindows_Click(object sender, RoutedEventArgs e)
        {
            if (sender is CheckBox cb && cb.Tag is string id)
            {
                BrowserConfigManager.Instance.SetCombineWindows(id, cb.IsChecked == true);
            }
        }

        private void ExtId_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (sender is TextBox tb && tb.Tag is string id)
            {
                _extensionIdInputs[id] = tb.Text;

                // Update the corresponding view model
                var vm = _browserRows.FirstOrDefault(b => b.Id == id);
                if (vm != null)
                {
                    vm.CurrentExtId = tb.Text;
                    vm.NotifyAll();
                }
            }
        }

        // ---- Shortcut Recording ----

        private void ShortcutButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string target)
            {
                _recordingShortcutTarget = target;
                btn.Content = "Press shortcut...";
                btn.Focus();
            }
        }

        private void OnPreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (string.IsNullOrEmpty(_recordingShortcutTarget)) return;

            // Need at least one modifier
            var mods = Keyboard.Modifiers;
            if (mods == ModifierKeys.None) return;

            int vkCode = KeyInterop.VirtualKeyFromKey(e.Key == Key.System ? e.SystemKey : e.Key);
            if (vkCode == 0) return;

            // Don't record modifier keys themselves
            if (e.Key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
                or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin or Key.System)
                return;

            var modFlags = ModifierKeysFlag.None;
            if (mods.HasFlag(ModifierKeys.Control)) modFlags |= ModifierKeysFlag.Control;
            if (mods.HasFlag(ModifierKeys.Alt)) modFlags |= ModifierKeysFlag.Alt;
            if (mods.HasFlag(ModifierKeys.Shift)) modFlags |= ModifierKeysFlag.Shift;
            if (mods.HasFlag(ModifierKeys.Windows)) modFlags |= ModifierKeysFlag.Win;

            var newShortcut = new ShortcutConfig { VkCode = vkCode, Modifiers = modFlags };

            if (_recordingShortcutTarget == "tabSwitch")
                BrowserConfigManager.Instance.Shortcuts.TabSwitch = newShortcut;
            else if (_recordingShortcutTarget == "copyUrl")
                BrowserConfigManager.Instance.Shortcuts.CopyUrl = newShortcut;

            BrowserConfigManager.Instance.SaveShortcuts();
            _recordingShortcutTarget = "";

            RefreshShortcutButtons();
            e.Handled = true;
        }

        private void ResetShortcuts_Click(object sender, RoutedEventArgs e)
        {
            BrowserConfigManager.Instance.Shortcuts = ShortcutsConfiguration.Defaults;
            BrowserConfigManager.Instance.SaveShortcuts();
            RefreshShortcutButtons();
        }

        // ---- Footer ----

        private void CheckUpdates_Click(object sender, RoutedEventArgs e)
        {
            // Trigger update check
            DebugLogger.Log("Manual update check requested");
        }

        private void Done_Click(object sender, RoutedEventArgs e)
        {
            if (BrowserConfigManager.Instance.Browsers.Any(b => b.IsEnabled))
            {
                Close();
            }
        }
    }

    // ---- View Model ----

    public class BrowserRowViewModel : INotifyPropertyChanged
    {
        private readonly BrowserInfo _browser;
        private bool _isExpanded;
        public string CurrentExtId { get; set; } = "";

        public BrowserRowViewModel(BrowserInfo browser, bool isExpanded)
        {
            _browser = browser;
            _isExpanded = isExpanded;
            CurrentExtId = browser.ExtensionId ?? "";
        }

        public string Id => _browser.Id;
        public string DisplayName => _browser.AppName;
        public string? IconPath => _browser.InstalledPath; // Will need icon extraction
        public bool CombineAllWindows => _browser.CombineAllWindows;

        public Visibility IsEnabledVisible => _browser.IsEnabled ? Visibility.Visible : Visibility.Collapsed;
        public Visibility IsNotEnabledVisible => !_browser.IsEnabled ? Visibility.Visible : Visibility.Collapsed;
        public Visibility ExpandedVisibility => _isExpanded ? Visibility.Visible : Visibility.Collapsed;

        public string ExtensionIdPrompt => $"Paste the extension ID from {_browser.Name}";
        public bool CanEnable => CurrentExtId.Length == 32;

        public Visibility CharCountVisibility =>
            !string.IsNullOrEmpty(CurrentExtId) && CurrentExtId.Length != 32
                ? Visibility.Visible : Visibility.Collapsed;

        public string CharCountText => $"{CurrentExtId.Length}/32 characters";

        public void NotifyAll()
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CanEnable)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CharCountVisibility)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CharCountText)));
        }

        public event PropertyChangedEventHandler? PropertyChanged;
    }
}
