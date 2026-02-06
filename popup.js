// Query connection status from service worker with actual ping test
const statusEl = document.getElementById("status");
const statusTextEl = document.getElementById("status-text");

// Set initial checking state
statusEl.className = "status disconnected";
statusTextEl.textContent = "Checking connection...";

// Request a real ping test from the service worker
chrome.runtime.sendMessage({ action: "ping_native_host" }, function(response) {
  if (chrome.runtime.lastError) {
    statusEl.className = "status disconnected";
    statusTextEl.textContent = "Extension not responding";
    return;
  }

  if (response && response.connected) {
    statusEl.className = "status connected";
    statusTextEl.textContent = "Connected to Tab Switcher app";
  } else {
    statusEl.className = "status disconnected";
    statusTextEl.textContent = "Not connected — is the app running?";
  }
});

// Version info and update banner
function compareVersions(a, b) {
  var partsA = a.split(".").map(Number);
  var partsB = b.split(".").map(Number);
  for (var i = 0; i < Math.max(partsA.length, partsB.length); i++) {
    var numA = partsA[i] || 0;
    var numB = partsB[i] || 0;
    if (numA < numB) return -1;
    if (numA > numB) return 1;
  }
  return 0;
}

var versionLabel = document.getElementById("version-label");
var currentVersion = chrome.runtime.getManifest().version;
versionLabel.textContent = "v" + currentVersion;

// Load custom shortcut display from storage
chrome.storage.local.get("shortcuts", function(data) {
  if (data.shortcuts) {
    if (data.shortcuts.tabSwitch) {
      var el = document.getElementById("tab-switch-keys");
      if (el) el.innerHTML = '<span class="key">' + data.shortcuts.tabSwitch + '</span>';
    }
    if (data.shortcuts.copyUrl) {
      var el = document.getElementById("copy-url-keys");
      if (el) el.innerHTML = '<span class="key">' + data.shortcuts.copyUrl + '</span>';
    }
  }
});

chrome.runtime.sendMessage({ action: "get_version_info" }, function(info) {
  if (chrome.runtime.lastError || !info) return;

  var banner = document.getElementById("update-banner");

  // Priority 1: CWS migration banner for manual installs
  if (info.isManualInstall && info.chromeWebStoreUrl) {
    banner.className = "update-banner cws";
    banner.innerHTML = 'Now on the Chrome Web Store! <a href="' + info.chromeWebStoreUrl + '" target="_blank">Install for automatic updates</a>';
    banner.style.display = "block";
    return;
  }

  // Priority 2: Update available for manual installs
  if (info.isManualInstall && info.latestExtensionVersion && compareVersions(currentVersion, info.latestExtensionVersion) < 0) {
    banner.className = "update-banner update";
    banner.innerHTML = 'Update available (v' + info.latestExtensionVersion + ') — <a href="https://tabswitcher.app/setup" target="_blank">Download</a>';
    banner.style.display = "block";
  }
});
