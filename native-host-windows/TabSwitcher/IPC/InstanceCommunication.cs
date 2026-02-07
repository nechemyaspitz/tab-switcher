using System;
using System.Collections.Concurrent;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using TabSwitcher.Helpers;

namespace TabSwitcher.IPC
{
    /// <summary>
    /// Named-pipe IPC between native host instances.
    /// Replaces NSDistributedNotificationCenter (main.swift:2354-2498).
    /// Leader runs a pipe server; non-leaders connect as clients.
    /// </summary>
    public class InstanceCommunication
    {
        private readonly bool _isLeader;
        private CancellationTokenSource? _cts;
        private readonly ConcurrentBag<NamedPipeServerStream> _serverConnections = new();
        private NamedPipeClientStream? _clientPipe;
        private StreamWriter? _clientWriter;

        // Events matching the notification names from main.swift:2354-2360
        public event Action<string, bool, bool, string>? OnCtrlTab;      // direction, showUI, combineWindows, targetBrowser
        public event Action<string>? OnCtrlRelease;                        // targetBrowser
        public event Action<bool, string>? OnRequestShowUI;                // combineWindows, targetBrowser
        public event Action<string>? OnCopyUrl;                            // targetBrowser
        public event Action? OnShortcutsChanged;
        public event Action? OnLeaderResigned;
        public event Action? OnShowConfig;

        public InstanceCommunication(bool isLeader)
        {
            _isLeader = isLeader;
        }

        public void Start()
        {
            _cts = new CancellationTokenSource();

            if (_isLeader)
            {
                Task.Run(() => RunServer(_cts.Token));
                DebugLogger.Log("IPC pipe server started");
            }
            else
            {
                Task.Run(() => ConnectAsClient(_cts.Token));
                DebugLogger.Log("IPC pipe client connecting");
            }
        }

        public void Stop()
        {
            _cts?.Cancel();

            if (_isLeader)
            {
                // Notify clients that leader is resigning
                BroadcastMessage(new { type = "leaderResigned" });
            }

            _clientPipe?.Dispose();
            foreach (var conn in _serverConnections)
            {
                try { conn.Dispose(); } catch { }
            }
        }

        // ---- Posting messages (called by KeyboardHook) ----

        public void PostCtrlTab(string direction, bool showUI, bool combineWindows, string targetBrowser)
        {
            var msg = new { type = "ctrlTab", direction, showUI, combineWindows, targetBrowser };
            if (_isLeader)
            {
                BroadcastMessage(msg);
                // Also invoke locally for the leader's own connections
                OnCtrlTab?.Invoke(direction, showUI, combineWindows, targetBrowser);
            }
            else
            {
                SendToLeader(msg);
            }
        }

        public void PostCtrlRelease(string targetBrowser)
        {
            var msg = new { type = "ctrlRelease", targetBrowser };
            if (_isLeader)
            {
                BroadcastMessage(msg);
                OnCtrlRelease?.Invoke(targetBrowser);
            }
            else
            {
                SendToLeader(msg);
            }
        }

        public void PostRequestShowUI(bool combineWindows, string targetBrowser)
        {
            var msg = new { type = "requestShowUI", combineWindows, targetBrowser };
            if (_isLeader)
            {
                BroadcastMessage(msg);
                OnRequestShowUI?.Invoke(combineWindows, targetBrowser);
            }
            else
            {
                SendToLeader(msg);
            }
        }

        public void PostCopyUrl(string targetBrowser)
        {
            var msg = new { type = "copyUrl", targetBrowser };
            if (_isLeader)
            {
                BroadcastMessage(msg);
                OnCopyUrl?.Invoke(targetBrowser);
            }
            else
            {
                SendToLeader(msg);
            }
        }

        public void PostShortcutsChanged()
        {
            var msg = new { type = "shortcutsChanged" };
            if (_isLeader)
            {
                BroadcastMessage(msg);
                OnShortcutsChanged?.Invoke();
            }
            else
            {
                SendToLeader(msg);
            }
        }

        // ---- Server (Leader) ----

        private async Task RunServer(CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                try
                {
                    var server = new NamedPipeServerStream(
                        Constants.IpcPipeName,
                        PipeDirection.InOut,
                        NamedPipeServerStream.MaxAllowedServerInstances,
                        PipeTransmissionMode.Byte,
                        PipeOptions.Asynchronous);

                    await server.WaitForConnectionAsync(ct);
                    _serverConnections.Add(server);
                    DebugLogger.Log("IPC client connected to server");

                    // Handle this client in a separate task
                    _ = Task.Run(() => HandleServerClient(server, ct), ct);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    DebugLogger.Log($"IPC server error: {ex.Message}");
                    await Task.Delay(1000, ct);
                }
            }
        }

        private async Task HandleServerClient(NamedPipeServerStream server, CancellationToken ct)
        {
            try
            {
                using var reader = new StreamReader(server, Encoding.UTF8);
                while (!ct.IsCancellationRequested && server.IsConnected)
                {
                    var line = await reader.ReadLineAsync();
                    if (line == null) break;

                    HandleReceivedMessage(line);

                    // Re-broadcast to other clients
                    BroadcastMessage(line, exclude: server);
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"IPC client handler error: {ex.Message}");
            }
        }

        private void BroadcastMessage(object msg, NamedPipeServerStream? exclude = null)
        {
            var json = JsonSerializer.Serialize(msg);
            BroadcastMessage(json, exclude);
        }

        private void BroadcastMessage(string json, NamedPipeServerStream? exclude = null)
        {
            foreach (var conn in _serverConnections)
            {
                if (conn == exclude || !conn.IsConnected) continue;
                try
                {
                    var writer = new StreamWriter(conn, Encoding.UTF8, leaveOpen: true) { AutoFlush = true };
                    writer.WriteLine(json);
                }
                catch
                {
                    // Client disconnected
                }
            }
        }

        // ---- Client (Non-Leader) ----

        private async Task ConnectAsClient(CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                try
                {
                    _clientPipe = new NamedPipeClientStream(".", Constants.IpcPipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
                    await _clientPipe.ConnectAsync(5000, ct);
                    _clientWriter = new StreamWriter(_clientPipe, Encoding.UTF8) { AutoFlush = true };

                    DebugLogger.Log("IPC connected to leader");

                    using var reader = new StreamReader(_clientPipe, Encoding.UTF8);
                    while (!ct.IsCancellationRequested && _clientPipe.IsConnected)
                    {
                        var line = await reader.ReadLineAsync();
                        if (line == null) break;
                        HandleReceivedMessage(line);
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    DebugLogger.Log($"IPC client error: {ex.Message}");
                }

                // Reconnect after delay
                if (!ct.IsCancellationRequested)
                    await Task.Delay(2000, ct);
            }
        }

        private void SendToLeader(object msg)
        {
            try
            {
                if (_clientWriter != null && _clientPipe?.IsConnected == true)
                {
                    var json = JsonSerializer.Serialize(msg);
                    _clientWriter.WriteLine(json);
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"IPC send to leader error: {ex.Message}");
            }
        }

        // ---- Message Dispatch ----

        private void HandleReceivedMessage(string json)
        {
            try
            {
                var doc = JsonNode.Parse(json)?.AsObject();
                if (doc == null) return;

                var type = doc["type"]?.GetValue<string>();
                switch (type)
                {
                    case "ctrlTab":
                        OnCtrlTab?.Invoke(
                            doc["direction"]?.GetValue<string>() ?? "",
                            doc["showUI"]?.GetValue<bool>() ?? false,
                            doc["combineWindows"]?.GetValue<bool>() ?? false,
                            doc["targetBrowser"]?.GetValue<string>() ?? "");
                        break;

                    case "ctrlRelease":
                        OnCtrlRelease?.Invoke(doc["targetBrowser"]?.GetValue<string>() ?? "");
                        break;

                    case "requestShowUI":
                        OnRequestShowUI?.Invoke(
                            doc["combineWindows"]?.GetValue<bool>() ?? false,
                            doc["targetBrowser"]?.GetValue<string>() ?? "");
                        break;

                    case "copyUrl":
                        OnCopyUrl?.Invoke(doc["targetBrowser"]?.GetValue<string>() ?? "");
                        break;

                    case "shortcutsChanged":
                        OnShortcutsChanged?.Invoke();
                        break;

                    case "leaderResigned":
                        OnLeaderResigned?.Invoke();
                        break;

                    case "showConfig":
                        OnShowConfig?.Invoke();
                        break;
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"IPC message parse error: {ex.Message}");
            }
        }
    }
}
