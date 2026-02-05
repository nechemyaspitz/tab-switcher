// Query connection status from service worker
chrome.runtime.sendMessage({ action: "get_connection_status" }, function(response) {
  const statusEl = document.getElementById("status");
  const statusTextEl = document.getElementById("status-text");
  
  if (chrome.runtime.lastError || !response) {
    statusEl.className = "status disconnected";
    statusTextEl.textContent = "Extension not responding";
    return;
  }
  
  if (response.connected) {
    statusEl.className = "status connected";
    statusTextEl.textContent = "Connected to Tab Switcher app";
  } else {
    statusEl.className = "status disconnected";
    statusTextEl.textContent = "Not connected — is the app running?";
  }
});