using System;
using System.Linq;
using System.Threading;
using System.Windows;
using TabSwitcher.Helpers;
using TabSwitcher.IPC;
using TabSwitcher.Keyboard;
using TabSwitcher.NativeMessaging;
using TabSwitcher.Services;
using TabSwitcher.Views;

namespace TabSwitcher
{
    public partial class App : Application
    {
        private NativeMessagingHost? _nativeMessaging;
        private KeyboardHook? _keyboardHook;
        private LeaderElection? _leaderElection;
        private InstanceCommunication? _ipc;
        private UpdateService? _updateService;
        private TabSwitcherOverlay? _overlay;
        private ToastOverlay? _toastOverlay;
        private SetupWindow? _setupWindow;

        public bool LaunchedDirectly { get; private set; }
        public string? OwnerBrowserId { get; set; }
        public uint? OwnerBrowserProcessId { get; set; }

        public static App Instance => (App)Current;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            Constants.EnsureAppDataDir();
            DebugLogger.Log($"Tab Switcher Native Host starting (PID {Environment.ProcessId})...");

            LaunchedDirectly = DetectLaunchMode(e.Args);
            DebugLogger.Log($"Launched directly: {LaunchedDirectly}");

            // Initialize browser config
            BrowserConfigManager.Instance.LoadConfig();
            BrowserConfigManager.Instance.LoadShortcuts();
            BrowserConfigManager.Instance.FetchRemoteBrowserListAsync();

            // Leader election for keyboard hook
            _leaderElection = new LeaderElection();
            bool isLeader = _leaderElection.TryBecomeLeader();
            DebugLogger.Log($"Event tap leader: {isLeader}");

            // Setup IPC
            _ipc = new InstanceCommunication(isLeader);

            // Create overlay windows (hidden initially)
            _overlay = new TabSwitcherOverlay();
            _toastOverlay = new ToastOverlay();

            // Setup keyboard hook if we're the leader
            if (isLeader)
            {
                _keyboardHook = new KeyboardHook(_ipc);
                _keyboardHook.Install();
                DebugLogger.Log("Keyboard hook installed (we are the leader)");
            }

            // Setup IPC message handling
            _ipc.OnCtrlTab += OnIpcCtrlTab;
            _ipc.OnCtrlRelease += OnIpcCtrlRelease;
            _ipc.OnRequestShowUI += OnIpcRequestShowUI;
            _ipc.OnCopyUrl += OnIpcCopyUrl;
            _ipc.OnShortcutsChanged += OnIpcShortcutsChanged;
            _ipc.OnLeaderResigned += OnIpcLeaderResigned;
            _ipc.Start();

            if (!LaunchedDirectly)
            {
                // Native messaging mode
                DetectParentBrowser();

                _nativeMessaging = new NativeMessagingHost();
                _nativeMessaging.OnMessageReceived += OnNativeMessage;
                _nativeMessaging.OnDisconnected += OnNativeDisconnected;
                _nativeMessaging.Start();
                _nativeMessaging.SendAction("ready");
                DebugLogger.Log("Ready message sent");
            }
            else
            {
                // Direct launch mode - show setup window
                DebugLogger.Log("Direct launch - showing setup window");
                ShowSetupWindow();
            }

            // Start update checking
            _updateService = new UpdateService(LaunchedDirectly);
            _updateService.Start();
        }

        private bool DetectLaunchMode(string[] args)
        {
            // Check for chrome-extension:// argument (native messaging launch).
            // This is the reliable indicator — Chrome always passes this arg when launching native messaging hosts.
            // Note: Console.IsInputRedirected is NOT reliable here because WinExe apps have no console,
            // which causes IsInputRedirected to return true even for direct launches.
            if (args.Any(a => a.StartsWith("chrome-extension://")))
            {
                DebugLogger.Log("Detected chrome-extension:// arg - launched via native messaging");
                return false;
            }

            DebugLogger.Log("No chrome-extension:// arg - direct launch");
            return true;
        }

        private void DetectParentBrowser()
        {
            var result = BrowserDetector.DetectParentBrowser();
            if (result != null)
            {
                OwnerBrowserId = result.Value.browserId;
                OwnerBrowserProcessId = result.Value.processId;
                DebugLogger.Log($"Auto-detected owner browser: {OwnerBrowserId} with PID {OwnerBrowserProcessId}");
            }
            else
            {
                DebugLogger.Log("WARNING: Could not auto-detect browser, will wait for registration");
            }
        }

        // ---- Native Messaging Handlers ----

        private void OnNativeMessage(NativeMessage message)
        {
            DebugLogger.Log($"Handling action: {message.Action}");

            switch (message.Action)
            {
                case "show_switcher":
                    Dispatcher.Invoke(() => _overlay?.ShowSwitcher(message));
                    break;

                case "update_selection":
                    if (message.SelectedIndex.HasValue)
                        Dispatcher.Invoke(() => _overlay?.UpdateSelection(message.SelectedIndex.Value));
                    break;

                case "hide_switcher":
                    Dispatcher.Invoke(() => _overlay?.HideSwitcher());
                    break;

                case "register":
                    HandleRegister(message);
                    break;

                case "ping":
                    DebugLogger.Log("Received ping, sending pong");
                    _nativeMessaging?.SendMessage(new { action = "pong" });
                    break;

                case "url_copied":
                    if (message.Url != null)
                    {
                        DebugLogger.Log($"Received URL to copy: {message.Url}");
                        Dispatcher.Invoke(() =>
                        {
                            try { Clipboard.SetText(message.Url); } catch { }
                            _toastOverlay?.ShowToast("Copied!", message.Url);
                        });
                    }
                    break;
            }
        }

        private void HandleRegister(NativeMessage message)
        {
            if (message.ExtensionVersion != null)
            {
                DebugLogger.Log($"Extension version: {message.ExtensionVersion}");
                _updateService?.SetExtensionVersion(message.ExtensionVersion);
            }

            if (message.BundleId != null)
            {
                if (OwnerBrowserId == null)
                {
                    OwnerBrowserId = message.BundleId;
                    if (OwnerBrowserProcessId == null)
                    {
                        var detected = BrowserDetector.DetectParentBrowser();
                        if (detected != null)
                        {
                            OwnerBrowserProcessId = detected.Value.processId;
                            DebugLogger.Log($"Registered with browser (from extension): {message.BundleId} with late-detected PID {OwnerBrowserProcessId}");
                        }
                    }
                }

                var shortcuts = new
                {
                    tabSwitch = BrowserConfigManager.Instance.Shortcuts.TabSwitch.DisplayString,
                    copyUrl = BrowserConfigManager.Instance.Shortcuts.CopyUrl.DisplayString
                };
                _nativeMessaging?.SendMessage(new
                {
                    action = "registered",
                    bundleId = OwnerBrowserId ?? message.BundleId,
                    shortcuts
                });
            }
        }

        private void OnNativeDisconnected()
        {
            DebugLogger.Log("Connection closed (EOF on stdin) - extension disconnected, exiting...");
            Dispatcher.Invoke(() => Shutdown());
        }

        // ---- IPC Handlers ----

        private void OnIpcCtrlTab(string direction, bool showUI, bool combineWindows, string targetBrowser)
        {
            if (OwnerBrowserId == null || OwnerBrowserId != targetBrowser) return;

            DebugLogger.Log($"Received ctrl-tab for our browser: direction={direction}, showUI={showUI}");
            _nativeMessaging?.SendMessage(new
            {
                action = direction,
                show_ui = showUI,
                current_window_only = !combineWindows
            });
        }

        private void OnIpcCtrlRelease(string targetBrowser)
        {
            if (OwnerBrowserId == null || OwnerBrowserId != targetBrowser) return;

            DebugLogger.Log("Received ctrl-release notification");
            _nativeMessaging?.SendAction("end_switch");
        }

        private void OnIpcRequestShowUI(bool combineWindows, string targetBrowser)
        {
            if (OwnerBrowserId == null || OwnerBrowserId != targetBrowser) return;

            DebugLogger.Log("Received request-show-ui notification");
            _nativeMessaging?.SendMessage(new
            {
                action = "request_show_ui",
                current_window_only = !combineWindows
            });
        }

        private void OnIpcCopyUrl(string targetBrowser)
        {
            if (OwnerBrowserId == null || OwnerBrowserId != targetBrowser) return;

            DebugLogger.Log("Received copy-url notification for our browser");
            _nativeMessaging?.SendMessage(new { action = "copy_url" });
        }

        private void OnIpcShortcutsChanged()
        {
            DebugLogger.Log("Received shortcuts-changed notification, reloading");
            BrowserConfigManager.Instance.LoadShortcuts();
        }

        private void OnIpcLeaderResigned()
        {
            DebugLogger.Log("Leader resigned, attempting to take over");
            if (_leaderElection != null && !_leaderElection.IsLeader)
            {
                Thread.Sleep(100);
                if (_leaderElection.TryBecomeLeader())
                {
                    _keyboardHook = new KeyboardHook(_ipc!);
                    _keyboardHook.Install();
                    DebugLogger.Log("Successfully became new keyboard hook leader");
                }
            }
        }

        // ---- UI ----

        public void ShowSetupWindow()
        {
            if (_setupWindow == null)
            {
                _setupWindow = new SetupWindow();
                _setupWindow.Closed += (s, e) => _setupWindow = null;
            }
            _setupWindow.Show();
            _setupWindow.Activate();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            DebugLogger.Log("Application exiting - cleaning up");
            _keyboardHook?.Uninstall();
            _leaderElection?.Release();
            _ipc?.Stop();
            _nativeMessaging?.Stop();
            base.OnExit(e);
        }
    }
}
