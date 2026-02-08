using System;
using System.Threading;
using TabSwitcher.Helpers;

namespace TabSwitcher.IPC
{
    /// <summary>
    /// Mutex-based leader election for keyboard hook ownership.
    /// Port of tryBecomeEventTapLeader (main.swift:2292-2334).
    /// Uses a named Mutex instead of file lock — auto-releases on crash (no stale lock problem).
    /// </summary>
    public class LeaderElection : IDisposable
    {
        private Mutex? _mutex;
        public bool IsLeader { get; private set; }

        /// <summary>
        /// Try to acquire leadership. Returns true if this instance is now the leader.
        /// </summary>
        public bool TryBecomeLeader()
        {
            try
            {
                _mutex = new Mutex(false, Constants.EventTapMutexName, out bool createdNew);

                if (createdNew)
                {
                    IsLeader = true;
                    DebugLogger.Log($"We (PID {Environment.ProcessId}) are now the event tap leader");
                    return true;
                }

                // Try to acquire with timeout
                bool acquired = _mutex.WaitOne(0);
                if (acquired)
                {
                    IsLeader = true;
                    DebugLogger.Log($"We (PID {Environment.ProcessId}) acquired the event tap mutex");
                    return true;
                }

                DebugLogger.Log($"Another instance owns the event tap, we (PID {Environment.ProcessId}) will listen only");
                return false;
            }
            catch (AbandonedMutexException)
            {
                // Previous owner crashed — we now own the mutex
                IsLeader = true;
                DebugLogger.Log($"Previous leader crashed — we (PID {Environment.ProcessId}) are the new leader");
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Log($"Failed to acquire mutex: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Release leadership. Port of cleanupEventTapLock (main.swift:2337-2351).
        /// </summary>
        public void Release()
        {
            if (IsLeader && _mutex != null)
            {
                try
                {
                    _mutex.ReleaseMutex();
                    DebugLogger.Log("Released event tap mutex");
                }
                catch (Exception ex)
                {
                    DebugLogger.Log($"Error releasing mutex: {ex.Message}");
                }
                IsLeader = false;
            }
        }

        public void Dispose()
        {
            Release();
            _mutex?.Dispose();
        }
    }
}
