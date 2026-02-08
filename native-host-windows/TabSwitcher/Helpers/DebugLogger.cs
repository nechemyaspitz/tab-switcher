using System;
using System.IO;

namespace TabSwitcher.Helpers
{
    public static class DebugLogger
    {
        private static readonly object _lock = new();
        private static bool _enabled = true;

        public static bool Enabled
        {
            get => _enabled;
            set => _enabled = value;
        }

        public static void Log(string message)
        {
            if (!_enabled) return;

            var timestamp = DateTime.UtcNow.ToString("O");
            var logMessage = $"[{timestamp}] TabSwitch: {message}";

            try
            {
                // Write to stderr (doesn't interfere with native messaging on stdout)
                Console.Error.WriteLine(logMessage);
            }
            catch
            {
                // Ignore stderr write failures
            }

            try
            {
                lock (_lock)
                {
                    File.AppendAllText(Constants.DebugLogPath, logMessage + Environment.NewLine);
                }
            }
            catch
            {
                // Ignore log file write failures
            }
        }
    }
}
