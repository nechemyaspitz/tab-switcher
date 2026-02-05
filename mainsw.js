/**
 * Tab Switcher - Chrome Extension Service Worker
 * Provides macOS-style Cmd+Tab switching for Chrome tabs
 */

// MRU (Most Recently Used) tab tracking
var mru = [];
var initialized = false;

// Switch state
var slowSwitchOngoing = false;
var fastSwitchOngoing = false;
var nativeSwitchOngoing = false;
var intSwitchCount = 0;
var lastIntSwitchIndex = 0;
var slowswitchForward = false;

// Timer for legacy Alt shortcuts
var slowtimerValue = 1500;
var fasttimerValue = 200;
var timer;

// Debug logging (enabled for troubleshooting)
var loggingOn = true;

// Native messaging for Ctrl+Tab interception
var nativePort = null;
var nativeHostConnected = false;

// Thumbnail caching for visual tab switcher
var tabThumbnails = {}; // Map of tabId -> base64 thumbnail data
var tabThumbnailOrder = []; // Track order for LRU eviction
var MAX_THUMBNAILS = 20; // Limit memory usage - keep only 20 most recent thumbnails
var lastActiveTabId = null; // Track the last active tab for thumbnail capture

var log = function(str) {
	if(loggingOn) {
		console.log(str);
	}
}

// Welcome/setup page URL (update this once website is live)
var SETUP_PAGE_URL = "https://nechemyaspitz.github.io/tab-switcher/setup.html";

// Initialize on install/update
chrome.runtime.onInstalled.addListener((details) => {
	log("Extension " + details.reason);
	
	// Open setup page on first install
	if (details.reason === "install") {
		chrome.tabs.create({ url: SETUP_PAGE_URL });
	}
	
	initialize();
});

var processCommand = function(command) {
	log('Command recd:' + command);
	var fastswitch = true;
	slowswitchForward = false;
	if(command == "alt_switch_fast") {
		fastswitch = true;
	} else if(command == "alt_switch_slow_backward") {
		fastswitch = false;
		slowswitchForward = false;
	} else if(command == "alt_switch_slow_forward") {
		fastswitch = false;
		slowswitchForward = true;
	}

	if(!slowSwitchOngoing && !fastSwitchOngoing) {

		if(fastswitch) {
			fastSwitchOngoing = true;
		} else {
			slowSwitchOngoing = true;
		}
			log("TabSwitch::START_SWITCH");
			intSwitchCount = 0;
			doIntSwitch();

	} else if((slowSwitchOngoing && !fastswitch) || (fastSwitchOngoing && fastswitch)){
		log("TabSwitch::DO_INT_SWITCH");
		doIntSwitch();

	} else if(slowSwitchOngoing && fastswitch) {
		endSwitch();
		fastSwitchOngoing = true;
		log("TabSwitch::START_SWITCH");
		intSwitchCount = 0;
		doIntSwitch();

	} else if(fastSwitchOngoing && !fastswitch) {
		endSwitch();
		slowSwitchOngoing = true;
		log("TabSwitch::START_SWITCH");
		intSwitchCount = 0;
		doIntSwitch();
	}

	if(timer) {
		if(fastSwitchOngoing || slowSwitchOngoing) {
			clearTimeout(timer);
		}
	}
	if(fastswitch) {
		timer = setTimeout(function() {endSwitch()},fasttimerValue);
	} else {
		timer = setTimeout(function() {endSwitch()},slowtimerValue);
	}

};

chrome.commands.onCommand.addListener(processCommand);

// Handle messages from popup
chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
	if (request.action === "get_connection_status") {
		sendResponse({ connected: nativeHostConnected && nativePort !== null });
		return true;
	}
});

chrome.runtime.onStartup.addListener(function () {
	log("Extension startup");
	initialize();
});


var doIntSwitch = function() {
	log("TabSwitch:: in int switch, intSwitchCount: "+intSwitchCount+", mru.length: "+mru.length);
	if (intSwitchCount < mru.length && intSwitchCount >= 0) {
		var tabIdToMakeActive;
		//check if tab is still present
		//sometimes tabs have gone missing
		var invalidTab = true;
		var thisWindowId;
		if(slowswitchForward) {
			decrementSwitchCounter();	
		} else {
			incrementSwitchCounter();	
		}
		tabIdToMakeActive = mru[intSwitchCount];
		chrome.tabs.get(tabIdToMakeActive, function(tab) {
			if(tab) {
				thisWindowId = tab.windowId;
				invalidTab = false;

				chrome.windows.update(thisWindowId, {"focused":true});
				chrome.tabs.update(tabIdToMakeActive, {active:true, highlighted: true});
				lastIntSwitchIndex = intSwitchCount;
				//break;
			} else {
				log("TabSwitch:: in int switch, >>invalid tab found.intSwitchCount: "+intSwitchCount+", mru.length: "+mru.length);
				removeItemAtIndexFromMRU(intSwitchCount);
				if(intSwitchCount >= mru.length) {
					intSwitchCount = 0;
				}
				doIntSwitch();
			}
		});	

		
	}
}

var endSwitch = function() {
	log("TabSwitch::END_SWITCH");
	slowSwitchOngoing = false;
	fastSwitchOngoing = false;
	nativeSwitchOngoing = false;
	var tabId = mru[lastIntSwitchIndex];
	putExistingTabToTop(tabId);
	printMRUSimple();
}

chrome.tabs.onActivated.addListener(function(activeInfo){
	// Note: By the time this fires, the new tab is already visible
	// So we capture the NEW tab's thumbnail (the one we just switched to)
	// This ensures each tab's thumbnail is captured while it's visible
	lastActiveTabId = activeInfo.tabId;

	if(!slowSwitchOngoing && !fastSwitchOngoing && !nativeSwitchOngoing) {
		var index = mru.indexOf(activeInfo.tabId);

		//probably should not happen since tab created gets called first than activated for new tabs,
		// but added as a backup behavior to avoid orphan tabs
		if(index == -1) {
			log("Unexpected scenario hit with tab("+activeInfo.tabId+").")
			addTabToMRUAtFront(activeInfo.tabId)
		} else {
			putExistingTabToTop(activeInfo.tabId);	
		}
		
		// Capture thumbnail of the tab we just switched TO (after a brief delay for render)
		setTimeout(function() {
			captureThumbnail(activeInfo.tabId, activeInfo.windowId);
		}, 300);
	}
});

// Update thumbnail when page finishes loading
chrome.tabs.onUpdated.addListener(function(tabId, changeInfo, tab) {
	if (changeInfo.status === 'complete' && tab.active) {
		// Page finished loading, capture a fresh thumbnail after a short delay
		setTimeout(function() {
			captureThumbnail(tabId, tab.windowId);
		}, 500);
	}
});

chrome.tabs.onCreated.addListener(function(tab) {
	log("Tab create event fired with tab("+tab.id+")");
	addTabToMRUAtBack(tab.id);
});

chrome.tabs.onRemoved.addListener(function(tabId, removedInfo) {
	log("Tab remove event fired from tab("+tabId+")");
	removeTabFromMRU(tabId);
	// Clean up thumbnail when tab is closed
	delete tabThumbnails[tabId];
	var thumbIndex = tabThumbnailOrder.indexOf(tabId);
	if (thumbIndex !== -1) {
		tabThumbnailOrder.splice(thumbIndex, 1);
	}
});


var addTabToMRUAtBack = function(tabId) {

	var index = mru.indexOf(tabId);
	if(index == -1) {
		//add to the end of mru
		mru.splice(-1, 0, tabId);
	}

}
	
var addTabToMRUAtFront = function(tabId) {

	var index = mru.indexOf(tabId);
	if(index == -1) {
		//add to the front of mru
		mru.splice(0, 0,tabId);
	}
	
}
var putExistingTabToTop = function(tabId){
	var index = mru.indexOf(tabId);
	if(index != -1) {
		mru.splice(index, 1);
		mru.unshift(tabId);
	}
}

var removeTabFromMRU = function(tabId) {
	var index = mru.indexOf(tabId);
	if(index != -1) {
		mru.splice(index, 1);
	}
}

var removeItemAtIndexFromMRU = function(index) {
	if(index < mru.length) {
		mru.splice(index, 1);
	}
}

var incrementSwitchCounter = function() {
	intSwitchCount = (intSwitchCount+1)%mru.length;
}

var decrementSwitchCounter = function() {
	if(intSwitchCount == 0) {
		intSwitchCount = mru.length - 1;
	} else {
		intSwitchCount = intSwitchCount - 1;
	}
}

var initialize = function() {

	if(!initialized) {
		initialized = true;
		chrome.windows.getAll({populate:true},function(windows){
			windows.forEach(function(window){
				window.tabs.forEach(function(tab){
					mru.unshift(tab.id);
				});
			});
			log("MRU after init: "+mru);
		});
	}
}	

var printMRUSimple = function() {
	log("mru: " + mru);
}

// ============================================
// Thumbnail Capture for Visual Tab Switcher
// ============================================

var captureThumbnail = function(tabId, windowId) {
	// First check if the tab still exists and is in a valid state
	chrome.tabs.get(tabId, function(tab) {
		if (chrome.runtime.lastError || !tab) {
			log("Cannot capture thumbnail - tab doesn't exist: " + tabId);
			return;
		}
		
		// Skip chrome:// and other restricted URLs
		if (tab.url && (tab.url.startsWith('chrome://') || 
		                tab.url.startsWith('chrome-extension://') ||
		                tab.url.startsWith('devtools://') ||
		                tab.url.startsWith('edge://') ||
		                tab.url.startsWith('about:'))) {
			log("Skipping thumbnail capture for restricted URL: " + tab.url);
			return;
		}

		// Capture the visible tab as a low-quality JPEG
		chrome.tabs.captureVisibleTab(windowId, {
			format: 'jpeg',
			quality: 40  // Lower quality for smaller size and memory
		}, function(dataUrl) {
			if (chrome.runtime.lastError) {
				log("Failed to capture thumbnail: " + chrome.runtime.lastError.message);
				return;
			}
			if (dataUrl) {
				// Update LRU order
				var existingIndex = tabThumbnailOrder.indexOf(tabId);
				if (existingIndex !== -1) {
					tabThumbnailOrder.splice(existingIndex, 1);
				}
				tabThumbnailOrder.unshift(tabId); // Add to front (most recent)
				
				// Store thumbnail
				tabThumbnails[tabId] = dataUrl;
				
				// Evict old thumbnails if over limit
				while (tabThumbnailOrder.length > MAX_THUMBNAILS) {
					var oldestTabId = tabThumbnailOrder.pop();
					delete tabThumbnails[oldestTabId];
					log("Evicted old thumbnail for tab " + oldestTabId);
				}
				
				log("Captured thumbnail for tab " + tabId + " (total: " + tabThumbnailOrder.length + ")");
			}
		});
	});
};

// Capture thumbnail of the current active tab (for initial capture)
var captureCurrentTabThumbnail = function() {
	chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
		if (tabs && tabs.length > 0) {
			var tab = tabs[0];
			lastActiveTabId = tab.id;
			captureThumbnail(tab.id, tab.windowId);
		}
	});
};

// Get tab data for the visual switcher (includes thumbnails, titles, favicons)
// Uses filteredMru when in a native switch session, otherwise uses full mru
var getTabDataForSwitcher = async function() {
	var tabData = [];
	// Use filtered MRU during native switch, otherwise full MRU
	var mruToUse = nativeSwitchOngoing ? filteredMru : mru;
	
	for (var i = 0; i < mruToUse.length; i++) {
		var tabId = mruToUse[i];
		try {
			var tab = await chrome.tabs.get(tabId);
			if (tab) {
				tabData.push({
					id: tab.id,
					title: tab.title || 'Untitled',
					favIconUrl: tab.favIconUrl || '',
					thumbnail: tabThumbnails[tabId] || null,
					url: tab.url || ''
				});
			}
		} catch (e) {
			log("Error getting tab data for tab " + tabId + ": " + e.message);
		}
	}
	
	return tabData;
};

// ============================================
// Native Messaging for Ctrl+Tab interception
// ============================================

// Detect which browser we're running in and return its bundle ID
var detectBrowserBundleId = function() {
	var ua = navigator.userAgent;
	
	// Check for specific browsers (order matters - check more specific first)
	if (ua.includes("Edg/")) {
		return "com.microsoft.edgemac";
	} else if (ua.includes("Brave")) {
		return "com.brave.Browser";
	} else if (ua.includes("Vivaldi")) {
		return "com.vivaldi.Vivaldi";
	} else if (ua.includes("OPR/") || ua.includes("Opera")) {
		// Check for Opera GX vs regular Opera
		if (ua.includes("OPGX")) {
			return "com.operasoftware.OperaGX";
		}
		return "com.operasoftware.Opera";
	} else if (ua.includes("Arc/")) {
		return "company.thebrowser.Browser";
	} else if (ua.includes("Helium")) {
		return "net.imput.helium";
	} else if (ua.includes("Chromium")) {
		return "org.chromium.Chromium";
	} else if (ua.includes("Chrome")) {
		// Generic Chrome - could be Google Chrome or other Chromium-based
		return "com.google.Chrome";
	}
	
	// Fallback - assume Chrome
	return "com.google.Chrome";
};

var browserBundleId = detectBrowserBundleId();
log("Detected browser: " + browserBundleId);

var connectNativeHost = function() {
	if (nativePort) {
		log("Native host already connected");
		return;
	}

	try {
		nativePort = chrome.runtime.connectNative("com.tabswitcher.native");
		log("Connected to native host");

		nativePort.onMessage.addListener(function(message) {
			log("Native message received: " + JSON.stringify(message));
			
			// Mark connection as alive on any message
			nativeHostConnected = true;
			
			if (message.action === "ready") {
				log("Native host is ready, registering browser: " + browserBundleId);
				// Register this extension with its browser's bundle ID
				sendToNativeHost({ action: "register", bundleId: browserBundleId });
			} else if (message.action === "registered") {
				log("Successfully registered with native host for browser: " + message.bundleId);
			} else if (message.action === "pong") {
				// Ping response - connection is alive
				log("Received pong - connection alive");
			} else if (message.action === "cycle_next") {
				handleNativeCycle(1, message.show_ui, message.current_window_only);
			} else if (message.action === "cycle_prev") {
				handleNativeCycle(-1, message.show_ui, message.current_window_only);
			} else if (message.action === "request_show_ui") {
				handleRequestShowUI(message.current_window_only);
			} else if (message.action === "end_switch") {
				handleNativeEndSwitch();
			} else if (message.action === "error_no_accessibility") {
				log("Native host error: No accessibility permissions");
				nativeHostConnected = false;
			}
		});

		nativePort.onDisconnect.addListener(function() {
			log("Native host disconnected");
			if (chrome.runtime.lastError) {
				log("Native host error: " + chrome.runtime.lastError.message);
			}
			nativePort = null;
			nativeHostConnected = false;
			
			// Try to reconnect after a short delay
			setTimeout(connectNativeHost, 1000);
		});

	} catch (e) {
		log("Failed to connect to native host: " + e.message);
		nativePort = null;
		nativeHostConnected = false;
	}
};

// Send a message to the native host
var sendToNativeHost = function(message) {
	if (nativePort) {
		try {
			nativePort.postMessage(message);
			log("Sent to native host: " + JSON.stringify(message).substring(0, 200));
		} catch (e) {
			log("Error sending to native host: " + e.message);
		}
	} else {
		log("Cannot send to native host - not connected");
	}
};

// Track if UI has been shown during current switch
var uiShownDuringSwitch = false;

// Window-filtered MRU list (only tabs from current window)
var filteredMru = [];
var currentWindowOnly = false;

// Get filtered MRU based on current window setting
var getFilteredMru = async function() {
	if (!currentWindowOnly) {
		return mru;
	}
	
	// Get the current window
	try {
		var currentWindow = await chrome.windows.getCurrent();
		var currentWindowId = currentWindow.id;
		
		// Filter MRU to only include tabs from current window
		var filtered = [];
		for (var i = 0; i < mru.length; i++) {
			try {
				var tab = await chrome.tabs.get(mru[i]);
				if (tab && tab.windowId === currentWindowId) {
					filtered.push(mru[i]);
				}
			} catch (e) {
				// Tab may have been closed
			}
		}
		return filtered.length > 0 ? filtered : mru; // Fallback to all tabs if window has only 1 tab
	} catch (e) {
		log("Error filtering MRU by window: " + e.message);
		return mru;
	}
};

// Check if any window from this profile is currently focused
// This is critical for multi-profile support - only the focused profile should respond
var isThisProfileFocused = async function() {
	try {
		// Get all windows in this profile
		var allWindows = await chrome.windows.getAll({windowTypes: ['normal']});
		log("TabSwitch::Profile has " + allWindows.length + " windows");
		
		for (var win of allWindows) {
			log("TabSwitch::  Window id=" + win.id + " focused=" + win.focused + " state=" + win.state);
			if (win.focused) {
				log("TabSwitch::This profile has a focused window (id=" + win.id + ")");
				return true;
			}
		}
		log("TabSwitch::This profile has NO focused windows - ignoring command");
		return false;
	} catch (e) {
		log("TabSwitch::Error checking focused windows: " + e.message);
		// If we can't check, assume we're not focused to avoid conflicts
		return false;
	}
};

// Handle cycle in either direction
// direction: 1 for next, -1 for prev
// showUI: whether to show the visual switcher
var handleNativeCycle = async function(direction, showUI, windowOnly) {
	log("TabSwitch::NATIVE_CYCLE direction=" + direction + " showUI=" + showUI + " currentWindowOnly=" + windowOnly);
	
	// CRITICAL: Check if this profile's window is focused before responding
	// This prevents multiple profiles from all responding to the same Ctrl+Tab
	// Check on EVERY command, not just when starting
	var isFocused = await isThisProfileFocused();
	if (!isFocused) {
		log("TabSwitch::Ignoring cycle - this profile is not focused");
		// If we were in a switch but lost focus, end it
		if (nativeSwitchOngoing) {
			log("TabSwitch::Lost focus mid-switch, ending");
			nativeSwitchOngoing = false;
			uiShownDuringSwitch = false;
			filteredMru = [];
			currentWindowOnly = false;
		}
		return;
	}
	
	if (!nativeSwitchOngoing) {
		// Start a new native switch
		nativeSwitchOngoing = true;
		intSwitchCount = 0;
		uiShownDuringSwitch = false;
		currentWindowOnly = windowOnly !== false; // Default to true (current window only)
		filteredMru = await getFilteredMru();
		log("TabSwitch::Using " + (currentWindowOnly ? "current window" : "all windows") + ", filteredMru length: " + filteredMru.length);
	}
	
	if (filteredMru.length === 0) {
		log("TabSwitch::No tabs in filtered MRU");
		return;
	}
	
	// Move selection - but DON'T switch yet
	if (direction > 0) {
		intSwitchCount = (intSwitchCount + 1) % filteredMru.length;
	} else {
		if (intSwitchCount == 0) {
			intSwitchCount = filteredMru.length - 1;
		} else {
			intSwitchCount = intSwitchCount - 1;
		}
	}
	lastIntSwitchIndex = intSwitchCount;
	
	// Show UI if requested and not already shown
	if (showUI && !uiShownDuringSwitch) {
		uiShownDuringSwitch = true;
		var tabData = await getTabDataForSwitcher();
		sendToNativeHost({
			action: "show_switcher",
			tabs: tabData,
			selectedIndex: intSwitchCount
		});
	} else if (uiShownDuringSwitch) {
		// UI already shown - just update selection
		sendToNativeHost({
			action: "update_selection",
			selectedIndex: intSwitchCount
		});
	}
	// If showUI is false and UI hasn't been shown, do nothing visual
};

// Handle request to show UI (from delay timer)
// windowOnly parameter is passed for consistency but filteredMru should already be set
var handleRequestShowUI = async function(windowOnly) {
	log("TabSwitch::REQUEST_SHOW_UI windowOnly=" + windowOnly);
	
	// Double-check we're still the focused profile before showing UI
	var isFocused = await isThisProfileFocused();
	if (!isFocused) {
		log("TabSwitch::Ignoring show UI request - this profile is not focused");
		return;
	}
	
	if (nativeSwitchOngoing && !uiShownDuringSwitch) {
		uiShownDuringSwitch = true;
		var tabData = await getTabDataForSwitcher();
		sendToNativeHost({
			action: "show_switcher",
			tabs: tabData,
			selectedIndex: intSwitchCount
		});
	}
};

var handleNativeEndSwitch = async function() {
	log("TabSwitch::NATIVE_END_SWITCH, switching to index: " + lastIntSwitchIndex);
	
	// Only handle end switch if we were the one doing the switch
	// Check if this profile is focused OR if we had started a switch
	if (nativeSwitchOngoing) {
		// Tell native host to hide the switcher (if it was shown)
		if (uiShownDuringSwitch) {
			sendToNativeHost({
				action: "hide_switcher"
			});
		}
		uiShownDuringSwitch = false;
		
		// Double-check we're still the focused profile before activating tabs
		var isFocused = await isThisProfileFocused();
		if (!isFocused) {
			log("TabSwitch::Ignoring end switch - this profile is no longer focused");
			nativeSwitchOngoing = false;
			filteredMru = [];
			currentWindowOnly = false;
			return;
		}
		
		// NOW actually switch to the selected tab (use filteredMru which was set during this switch)
		var tabIdToActivate = filteredMru[lastIntSwitchIndex];
		if (tabIdToActivate) {
			chrome.tabs.get(tabIdToActivate, function(tab) {
				if (tab) {
					chrome.windows.update(tab.windowId, {"focused": true});
					chrome.tabs.update(tabIdToActivate, {active: true, highlighted: true});
				}
			});
		}
		
		// End the switch and update MRU
		endSwitch();
		
		// Reset filtered state
		filteredMru = [];
		currentWindowOnly = false;
	}
};

// Keep service worker alive (Chrome kills inactive workers after 30s)
var alivePort = null;
setInterval(() => {
	if (!alivePort) {
		alivePort = chrome.runtime.connect({ name: "keepalive" });
		alivePort.onDisconnect.addListener(() => { alivePort = null; });
	}
	if (alivePort) alivePort.postMessage({ ping: true });
}, 25000);

initialize();

// Connect to native host for Ctrl+Tab interception
connectNativeHost();

// Reconnect native host when this profile's window gains focus
// This fixes the issue where the service worker goes dormant when the profile is in the background
chrome.windows.onFocusChanged.addListener(function(windowId) {
	if (windowId !== chrome.windows.WINDOW_ID_NONE) {
		log("Window focus changed to: " + windowId);
		// Check if the native host connection is still alive
		if (!nativePort || !nativeHostConnected) {
			log("Native host connection lost, reconnecting...");
			connectNativeHost();
		} else {
			// Send a ping to verify the connection is still working
			try {
				sendToNativeHost({ action: "ping" });
			} catch (e) {
				log("Ping failed, reconnecting: " + e.message);
				nativePort = null;
				nativeHostConnected = false;
				connectNativeHost();
			}
		}
	}
});

// Capture initial thumbnail after a short delay (to let page load)
setTimeout(captureCurrentTabThumbnail, 2000);