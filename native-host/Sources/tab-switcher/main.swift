import Foundation
import AppKit
import SwiftUI
import Carbon.HIToolbox
import ApplicationServices
import Sparkle
import UserNotifications

let APP_VERSION = "3.7.4"

// MARK: - Keyboard Shortcut Configuration

func keyCodeToString(_ keyCode: Int64) -> String {
    switch Int(keyCode) {
    case kVK_Tab: return "⇥"
    case kVK_Return: return "↩"
    case kVK_Space: return "Space"
    case kVK_Delete: return "⌫"
    case kVK_Escape: return "⎋"
    case kVK_UpArrow: return "↑"
    case kVK_DownArrow: return "↓"
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_ANSI_A: return "A"
    case kVK_ANSI_B: return "B"
    case kVK_ANSI_C: return "C"
    case kVK_ANSI_D: return "D"
    case kVK_ANSI_E: return "E"
    case kVK_ANSI_F: return "F"
    case kVK_ANSI_G: return "G"
    case kVK_ANSI_H: return "H"
    case kVK_ANSI_I: return "I"
    case kVK_ANSI_J: return "J"
    case kVK_ANSI_K: return "K"
    case kVK_ANSI_L: return "L"
    case kVK_ANSI_M: return "M"
    case kVK_ANSI_N: return "N"
    case kVK_ANSI_O: return "O"
    case kVK_ANSI_P: return "P"
    case kVK_ANSI_Q: return "Q"
    case kVK_ANSI_R: return "R"
    case kVK_ANSI_S: return "S"
    case kVK_ANSI_T: return "T"
    case kVK_ANSI_U: return "U"
    case kVK_ANSI_V: return "V"
    case kVK_ANSI_W: return "W"
    case kVK_ANSI_X: return "X"
    case kVK_ANSI_Y: return "Y"
    case kVK_ANSI_Z: return "Z"
    case kVK_ANSI_0: return "0"
    case kVK_ANSI_1: return "1"
    case kVK_ANSI_2: return "2"
    case kVK_ANSI_3: return "3"
    case kVK_ANSI_4: return "4"
    case kVK_ANSI_5: return "5"
    case kVK_ANSI_6: return "6"
    case kVK_ANSI_7: return "7"
    case kVK_ANSI_8: return "8"
    case kVK_ANSI_9: return "9"
    case kVK_ANSI_Grave: return "`"
    case kVK_ANSI_Minus: return "-"
    case kVK_ANSI_Equal: return "="
    case kVK_ANSI_LeftBracket: return "["
    case kVK_ANSI_RightBracket: return "]"
    case kVK_ANSI_Backslash: return "\\"
    case kVK_ANSI_Semicolon: return ";"
    case kVK_ANSI_Quote: return "'"
    case kVK_ANSI_Comma: return ","
    case kVK_ANSI_Period: return "."
    case kVK_ANSI_Slash: return "/"
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    default: return "Key\(keyCode)"
    }
}

struct ShortcutConfig: Codable, Equatable {
    var keyCode: Int64
    var modifiers: UInt64

    var displayString: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
}

struct ShortcutsConfiguration: Codable {
    var tabSwitch: ShortcutConfig
    var copyUrl: ShortcutConfig

    static let defaults = ShortcutsConfiguration(
        tabSwitch: ShortcutConfig(
            keyCode: Int64(kVK_Tab),
            modifiers: CGEventFlags.maskControl.rawValue
        ),
        copyUrl: ShortcutConfig(
            keyCode: Int64(kVK_ANSI_C),
            modifiers: CGEventFlags([.maskCommand, .maskShift]).rawValue
        )
    )
}

// Global shortcut config (read by event tap callback — C function pointer can only read globals)
var tabSwitchKeyCode: Int64 = Int64(kVK_Tab)
var tabSwitchModifiers: UInt64 = CGEventFlags.maskControl.rawValue
var copyUrlKeyCode: Int64 = Int64(kVK_ANSI_C)
var copyUrlModifiers: UInt64 = CGEventFlags([.maskCommand, .maskShift]).rawValue

func updateShortcutGlobals(from config: ShortcutsConfiguration) {
    tabSwitchKeyCode = config.tabSwitch.keyCode
    tabSwitchModifiers = config.tabSwitch.modifiers
    copyUrlKeyCode = config.copyUrl.keyCode
    copyUrlModifiers = config.copyUrl.modifiers
}

// MARK: - Browser Configuration

// Minimal browser definition fetched from remote config
struct BrowserDefinition: Codable {
    let id: String
    let name: String
    let appName: String
    let nativeMessagingPath: String
}

struct BrowserInfo: Identifiable, Codable {
    let id: String // bundle identifier
    let name: String
    let nativeMessagingPath: String // relative to ~/Library/Application Support/
    var extensionId: String? // user-provided extension ID
    var isEnabled: Bool
    var combineAllWindows: Bool = false // false = only current window tabs, true = all windows
    var appName: String // display name for .app bundle lookup

    init(id: String, name: String, nativeMessagingPath: String, extensionId: String?, isEnabled: Bool, combineAllWindows: Bool = false, appName: String? = nil) {
        self.id = id
        self.name = name
        self.nativeMessagingPath = nativeMessagingPath
        self.extensionId = extensionId
        self.isEnabled = isEnabled
        self.combineAllWindows = combineAllWindows
        self.appName = appName ?? name
    }

    // Custom Codable decoder: defaults appName to name if missing (backwards compat with v3.6 configs)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nativeMessagingPath = try container.decode(String.self, forKey: .nativeMessagingPath)
        extensionId = try container.decodeIfPresent(String.self, forKey: .extensionId)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        combineAllWindows = try container.decodeIfPresent(Bool.self, forKey: .combineAllWindows) ?? false
        appName = try container.decodeIfPresent(String.self, forKey: .appName) ?? name
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, nativeMessagingPath, extensionId, isEnabled, combineAllWindows, appName
    }

    init(from definition: BrowserDefinition) {
        self.id = definition.id
        self.name = definition.name
        self.nativeMessagingPath = definition.nativeMessagingPath
        self.extensionId = nil
        self.isEnabled = false
        self.combineAllWindows = false
        self.appName = definition.appName
    }

    var fullNativeMessagingPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/\(nativeMessagingPath)"
    }

    // Check if browser is installed
    var isInstalled: Bool {
        let paths = [
            "/Applications/\(appName).app",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications/\(appName).app"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    var appPath: String? {
        let paths = [
            "/Applications/\(appName).app",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications/\(appName).app"
        ]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    var icon: NSImage? {
        guard let path = appPath else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
}

// Hardcoded fallback browser list — remote browsers.json takes priority
let knownBrowsers: [BrowserInfo] = [
    BrowserInfo(id: "com.google.Chrome", name: "Google Chrome",
                nativeMessagingPath: "Google/Chrome/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Google Chrome"),
    BrowserInfo(id: "com.google.Chrome.dev", name: "Google Chrome Dev",
                nativeMessagingPath: "Google/Chrome Dev/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Google Chrome Dev"),
    BrowserInfo(id: "com.google.Chrome.canary", name: "Google Chrome Canary",
                nativeMessagingPath: "Google/Chrome Canary/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Google Chrome Canary"),
    BrowserInfo(id: "com.brave.Browser", name: "Brave",
                nativeMessagingPath: "BraveSoftware/Brave-Browser/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Brave Browser"),
    BrowserInfo(id: "com.microsoft.edgemac", name: "Microsoft Edge",
                nativeMessagingPath: "Microsoft Edge/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Microsoft Edge"),
    BrowserInfo(id: "company.thebrowser.Browser", name: "Arc",
                nativeMessagingPath: "Arc/User Data/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Arc"),
    BrowserInfo(id: "com.vivaldi.Vivaldi", name: "Vivaldi",
                nativeMessagingPath: "Vivaldi/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Vivaldi"),
    BrowserInfo(id: "com.operasoftware.Opera", name: "Opera",
                nativeMessagingPath: "com.operasoftware.Opera/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Opera"),
    BrowserInfo(id: "com.operasoftware.OperaGX", name: "Opera GX",
                nativeMessagingPath: "com.operasoftware.OperaGX/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Opera GX"),
    BrowserInfo(id: "org.chromium.Chromium", name: "Chromium",
                nativeMessagingPath: "Chromium/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Chromium"),
    BrowserInfo(id: "net.imput.helium", name: "Helium",
                nativeMessagingPath: "net.imput.helium/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Helium"),
    BrowserInfo(id: "ai.perplexity.comet", name: "Comet",
                nativeMessagingPath: "Comet/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Comet"),
    BrowserInfo(id: "com.openai.atlas", name: "ChatGPT Atlas",
                nativeMessagingPath: "com.openai.atlas/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "ChatGPT Atlas"),
    BrowserInfo(id: "org.chromium.Thorium", name: "Thorium",
                nativeMessagingPath: "Thorium/NativeMessagingHosts",
                extensionId: nil, isEnabled: false, appName: "Thorium"),
]

// MARK: - Browser Configuration Manager

class BrowserConfigManager: ObservableObject {
    static let shared = BrowserConfigManager()
    
    @Published var browsers: [BrowserInfo] = []
    @Published var showingSetup = false
    @Published var shortcuts: ShortcutsConfiguration = .defaults
    @Published var showExtensionUpdateInstructions = false

    private let configURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("TabSwitcher")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("browser_config.json")
    }()

    private let cachedBrowserListURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("TabSwitcher")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("browser_list_cache.json")
    }()

    private let shortcutsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("TabSwitcher")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("shortcuts.json")
    }()

    init() {
        loadConfig()
        loadShortcuts()
        fetchRemoteBrowserList()
    }

    func loadShortcuts() {
        if let data = try? Data(contentsOf: shortcutsURL),
           let saved = try? JSONDecoder().decode(ShortcutsConfiguration.self, from: data) {
            shortcuts = saved
        }
        updateShortcutGlobals(from: shortcuts)
    }

    func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            try? data.write(to: shortcutsURL)
        }
        updateShortcutGlobals(from: shortcuts)
        // Notify other instances
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.tabswitcher.shortcutsChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
    
    /// Returns the base browser list: cached remote list if available, otherwise hardcoded fallback.
    private func baseBrowserList() -> [BrowserInfo] {
        // Try cached remote list first
        if let data = try? Data(contentsOf: cachedBrowserListURL),
           let definitions = try? JSONDecoder().decode([BrowserDefinition].self, from: data) {
            debugLog("Using cached remote browser list (\(definitions.count) browsers)")
            return definitions.map { BrowserInfo(from: $0) }
        }
        // Fall back to hardcoded list
        debugLog("Using hardcoded browser list (\(knownBrowsers.count) browsers)")
        return knownBrowsers
    }

    func loadConfig() {
        // Migrate: if old browsers.json exists, move it to new name
        let oldConfigURL = configURL.deletingLastPathComponent().appendingPathComponent("browsers.json")
        if FileManager.default.fileExists(atPath: oldConfigURL.path),
           !FileManager.default.fileExists(atPath: configURL.path) {
            try? FileManager.default.moveItem(at: oldConfigURL, to: configURL)
            debugLog("Migrated browsers.json to browser_config.json")
        }

        // Start with base browser list (cached remote or hardcoded fallback)
        var loadedBrowsers = baseBrowserList()

        // Try to load saved user config (enabled state, extension IDs)
        if let data = try? Data(contentsOf: configURL),
           let saved = try? JSONDecoder().decode([BrowserInfo].self, from: data) {
            // Merge saved config into browser list
            for (index, browser) in loadedBrowsers.enumerated() {
                if let savedBrowser = saved.first(where: { $0.id == browser.id }) {
                    loadedBrowsers[index].extensionId = savedBrowser.extensionId
                    loadedBrowsers[index].isEnabled = savedBrowser.isEnabled
                    loadedBrowsers[index].combineAllWindows = savedBrowser.combineAllWindows
                }
            }
            // Also include any saved browsers not in the base list (user had configured
            // a browser that was later removed from remote list — keep their config)
            for savedBrowser in saved where savedBrowser.isEnabled {
                if !loadedBrowsers.contains(where: { $0.id == savedBrowser.id }) {
                    loadedBrowsers.append(savedBrowser)
                }
            }
        }

        browsers = loadedBrowsers
    }

    /// Fetches the browser list from the website and caches it locally.
    /// On success, reloads the browser list to pick up any new browsers.
    func fetchRemoteBrowserList() {
        guard let url = URL(string: "https://tabswitcher.app/browsers.json") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                debugLog("Failed to fetch remote browser list: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            // Validate it's a proper browser list
            guard let definitions = try? JSONDecoder().decode([BrowserDefinition].self, from: data),
                  !definitions.isEmpty else {
                debugLog("Remote browser list was empty or invalid")
                return
            }

            // Cache it
            try? data.write(to: self.cachedBrowserListURL)
            debugLog("Cached remote browser list (\(definitions.count) browsers)")

            // Reload config on main thread to pick up new browsers
            DispatchQueue.main.async {
                self.loadConfig()
            }
        }.resume()
    }
    
    func saveConfig() {
        if let data = try? JSONEncoder().encode(browsers) {
            try? data.write(to: configURL)
        }
        updateManifests()
    }
    
    func enableBrowser(id: String, extensionId: String) {
        if let index = browsers.firstIndex(where: { $0.id == id }) {
            browsers[index].extensionId = extensionId
            browsers[index].isEnabled = true
            saveConfig()
        }
    }
    
    func disableBrowser(id: String) {
        if let index = browsers.firstIndex(where: { $0.id == id }) {
            browsers[index].isEnabled = false
            saveConfig()
        }
    }
    
    func setCombineWindows(id: String, combine: Bool) {
        if let index = browsers.firstIndex(where: { $0.id == id }) {
            browsers[index].combineAllWindows = combine
            saveConfig()
        }
    }
    
    func updateManifests() {
        // Use the actual path of the running app binary, not hardcoded path
        let nativeHostPath: String
        if let bundlePath = Bundle.main.executablePath {
            nativeHostPath = bundlePath
            debugLog("Using actual binary path for manifest: \(bundlePath)")
        } else {
            // Fallback to expected installation path
            nativeHostPath = "/Applications/Tab Switcher.app/Contents/MacOS/tab-switcher"
            debugLog("Using fallback binary path for manifest: \(nativeHostPath)")
        }
        
        for browser in browsers {
            let manifestDir = browser.fullNativeMessagingPath
            let manifestPath = "\(manifestDir)/com.tabswitcher.native.json"
            
            if browser.isEnabled, let extId = browser.extensionId, !extId.isEmpty {
                // Create manifest directory if needed
                try? FileManager.default.createDirectory(atPath: manifestDir, withIntermediateDirectories: true)
                
                // Create manifest
                let manifest: [String: Any] = [
                    "name": "com.tabswitcher.native",
                    "description": "Tab Switcher Native Helper",
                    "path": nativeHostPath,
                    "type": "stdio",
                    "allowed_origins": ["chrome-extension://\(extId)/"]
                ]
                
                if let data = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted) {
                    try? data.write(to: URL(fileURLWithPath: manifestPath))
                    debugLog("Created manifest for \(browser.name) at \(manifestPath)")
                }
            } else {
                // Remove manifest if disabled
                try? FileManager.default.removeItem(atPath: manifestPath)
            }
        }
    }
    
    var enabledBundleIds: Set<String> {
        Set(browsers.filter { $0.isEnabled }.map { $0.id })
    }
    
    var installedBrowsers: [BrowserInfo] {
        browsers.filter { $0.isInstalled }
    }
}

// MARK: - Sparkle Updater

final class UpdaterViewModel: ObservableObject {
    let updaterController: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func startUpdater() {
        updaterController.startUpdater()
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

let updaterViewModel = UpdaterViewModel()

// MARK: - Background Update Checker

class BackgroundUpdateChecker: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = BackgroundUpdateChecker()

    static let appUpdateCategory = "APP_UPDATE"
    static let extensionUpdateCategory = "EXTENSION_UPDATE"
    static let updateAction = "UPDATE_ACTION"

    var skipAppUpdateNotifications = false

    private var isUpdateCheckLeader = false
    private var checkTimer: Timer?
    private var connectedExtensionVersion: String?

    private let updateCheckerLockFile: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tabswitcher_updatechecker.lock")
    }()

    private let notifiedVersionsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("TabSwitcher")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("notified_versions.json")
    }()

    struct NotifiedVersions: Codable {
        var app: String?
        var ext: String?
    }

    struct VersionInfo: Codable {
        struct AppVersion: Codable {
            let version: String
            let downloadUrl: String
            let releaseNotes: String
        }
        struct ExtVersion: Codable {
            let version: String
            let chromeWebStoreUrl: String?
            let releaseNotes: String
        }
        let app: AppVersion
        let `extension`: ExtVersion
    }

    // MARK: - Setup

    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            debugLog("Notification permission: \(granted), error: \(error?.localizedDescription ?? "none")")
        }

        let updateAction = UNNotificationAction(
            identifier: BackgroundUpdateChecker.updateAction,
            title: "View Update",
            options: [.foreground]
        )

        let appCategory = UNNotificationCategory(
            identifier: BackgroundUpdateChecker.appUpdateCategory,
            actions: [updateAction],
            intentIdentifiers: []
        )

        let extCategory = UNNotificationCategory(
            identifier: BackgroundUpdateChecker.extensionUpdateCategory,
            actions: [updateAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([appCategory, extCategory])
    }

    func setExtensionVersion(_ version: String) {
        connectedExtensionVersion = version
    }

    // MARK: - Leader Election

    func tryBecomeUpdateCheckLeader() -> Bool {
        let myPid = getpid()

        if FileManager.default.fileExists(atPath: updateCheckerLockFile.path) {
            if let contents = try? String(contentsOf: updateCheckerLockFile, encoding: .utf8),
               let existingPid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if kill(existingPid, 0) == 0 {
                    if let app = NSRunningApplication(processIdentifier: existingPid),
                       app.bundleIdentifier == Bundle.main.bundleIdentifier {
                        return false
                    }
                }
                try? FileManager.default.removeItem(at: updateCheckerLockFile)
            } else {
                try? FileManager.default.removeItem(at: updateCheckerLockFile)
            }
        }

        do {
            try String(myPid).write(to: updateCheckerLockFile, atomically: true, encoding: .utf8)
            debugLog("We (PID \(myPid)) are the update check leader")
            return true
        } catch {
            return false
        }
    }

    func cleanupUpdateCheckLock() {
        if isUpdateCheckLeader {
            try? FileManager.default.removeItem(at: updateCheckerLockFile)
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.tabswitcher.updateCheckerResigned"),
                object: nil, userInfo: nil, deliverImmediately: true
            )
        }
    }

    func tryTakeOverLeadership() {
        guard !isUpdateCheckLeader else { return }
        if tryBecomeUpdateCheckLeader() {
            isUpdateCheckLeader = true
            debugLog("Took over as update check leader")
            startPeriodicChecks()
        }
    }

    // MARK: - Periodic Checking

    func startPeriodicChecks() {
        isUpdateCheckLeader = tryBecomeUpdateCheckLeader()
        guard isUpdateCheckLeader else {
            debugLog("Not the update check leader, skipping periodic checks")
            return
        }

        // First check after a short delay (give time for extension to register)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.checkForUpdates()
        }

        // Then every 4 hours
        checkTimer = Timer.scheduledTimer(withTimeInterval: 4 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    private func checkForUpdates() {
        guard isUpdateCheckLeader else { return }
        guard let url = URL(string: "https://tabswitcher.app/version.json") else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                debugLog("Version check failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            do {
                let info = try JSONDecoder().decode(VersionInfo.self, from: data)
                self.processVersionInfo(info)
            } catch {
                debugLog("Failed to decode version.json: \(error)")
            }
        }
        task.resume()
    }

    private func processVersionInfo(_ info: VersionInfo) {
        let notified = loadNotifiedVersions()

        // Check app version
        if !skipAppUpdateNotifications && isNewerVersion(info.app.version, than: APP_VERSION) {
            if notified.app != info.app.version {
                sendAppUpdateNotification(newVersion: info.app.version, releaseNotes: info.app.releaseNotes)
                saveNotifiedVersions(NotifiedVersions(app: info.app.version, ext: notified.ext))
            }
        }

        // Check extension version
        if let extVersion = connectedExtensionVersion,
           isNewerVersion(info.extension.version, than: extVersion) {
            if notified.ext != info.extension.version {
                sendExtensionUpdateNotification(newVersion: info.extension.version, currentVersion: extVersion)
                saveNotifiedVersions(NotifiedVersions(app: notified.app, ext: info.extension.version))
            }
        }
    }

    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    // MARK: - Persistence

    private func loadNotifiedVersions() -> NotifiedVersions {
        guard let data = try? Data(contentsOf: notifiedVersionsURL),
              let versions = try? JSONDecoder().decode(NotifiedVersions.self, from: data) else {
            return NotifiedVersions()
        }
        return versions
    }

    private func saveNotifiedVersions(_ versions: NotifiedVersions) {
        if let data = try? JSONEncoder().encode(versions) {
            try? data.write(to: notifiedVersionsURL)
        }
    }

    // MARK: - Send Notifications

    private func sendAppUpdateNotification(newVersion: String, releaseNotes: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tab Switcher Update Available"
        content.body = "Version \(newVersion) is available (you have \(APP_VERSION)). \(releaseNotes)"
        content.sound = .default
        content.categoryIdentifier = BackgroundUpdateChecker.appUpdateCategory
        content.userInfo = ["type": "app", "version": newVersion]

        let request = UNNotificationRequest(identifier: "app-update-\(newVersion)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("Failed to send app update notification: \(error)")
            } else {
                debugLog("Sent app update notification for \(newVersion)")
            }
        }
    }

    private func sendExtensionUpdateNotification(newVersion: String, currentVersion: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tab Switcher Extension Update"
        content.body = "Extension v\(newVersion) is available (you have v\(currentVersion)). Click to see how to update."
        content.sound = .default
        content.categoryIdentifier = BackgroundUpdateChecker.extensionUpdateCategory
        content.userInfo = ["type": "extension", "version": newVersion]

        let request = UNNotificationRequest(identifier: "ext-update-\(newVersion)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("Failed to send extension update notification: \(error)")
            } else {
                debugLog("Sent extension update notification for \(newVersion)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String

        if type == "app" {
            handleAppUpdateClick()
        } else if type == "extension" {
            handleExtensionUpdateClick()
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    private func handleAppUpdateClick() {
        debugLog("User clicked app update notification")

        // Post distributed notification for any directly-launched instance to handle
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.tabswitcher.triggerAppUpdate"),
            object: nil, userInfo: nil, deliverImmediately: true
        )

        // Check if a directly-launched instance exists
        let hasDirectInstance = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.activationPolicy == .regular
        }

        if !hasDirectInstance {
            // No direct instance — handle it ourselves
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                allowConfigUI = true
                BrowserConfigManager.shared.showingSetup = true
                updaterViewModel.startUpdater()
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    updaterViewModel.checkForUpdates()
                }
            }
        }
    }

    private func handleExtensionUpdateClick() {
        debugLog("User clicked extension update notification")

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.tabswitcher.showExtensionUpdate"),
            object: nil, userInfo: nil, deliverImmediately: true
        )

        DispatchQueue.main.async {
            allowConfigUI = true
            BrowserConfigManager.shared.showingSetup = true
            BrowserConfigManager.shared.showExtensionUpdateInstructions = true
        }
    }
}

// MARK: - Shortcut Recorder

class ShortcutRecorderNSView: NSView {
    var onShortcutRecorded: ((Int64, UInt64) -> Void)?
    var displayString = ""
    var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        displayString = "Press shortcut..."
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func recordEvent(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        let keyCode = Int64(event.keyCode)
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !modifiers.isEmpty else { return false }

        var cgFlags: CGEventFlags = []
        if modifiers.contains(.control) { cgFlags.insert(.maskControl) }
        if modifiers.contains(.option) { cgFlags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { cgFlags.insert(.maskShift) }
        if modifiers.contains(.command) { cgFlags.insert(.maskCommand) }

        onShortcutRecorded?(keyCode, cgFlags.rawValue)
        isRecording = false
        needsDisplay = true
        return true
    }

    // performKeyEquivalent catches Tab and other keys that macOS normally intercepts
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recordEvent(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if recordEvent(event) { return }
        super.keyDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            needsDisplay = true
        }
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let bgColor: NSColor = isRecording ? .controlAccentColor.withAlphaComponent(0.15) : .controlBackgroundColor
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()

        NSColor.separatorColor.setStroke()
        path.stroke()

        let text = isRecording ? "Press shortcut..." : (displayString.isEmpty ? "Click to set" : displayString)
        let textColor: NSColor = isRecording ? .secondaryLabelColor : (displayString.isEmpty ? .tertiaryLabelColor : .labelColor)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: textColor
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        str.draw(in: textRect)
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: ShortcutConfig
    var onChange: (() -> Void)?

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.displayString = shortcut.displayString
        view.onShortcutRecorded = { keyCode, modifiers in
            shortcut = ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
            onChange?()
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.displayString = shortcut.displayString
        nsView.onShortcutRecorded = { keyCode, modifiers in
            shortcut = ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
            onChange?()
        }
        nsView.needsDisplay = true
    }
}

// MARK: - Setup Window View

struct SetupView: View {
    @ObservedObject var configManager = BrowserConfigManager.shared
    @ObservedObject var updater = updaterViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        if let icon = NSApp.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .padding(.bottom, 4)
                        }
                        Text("Tab Switcher")
                            .font(.system(size: 18, weight: .bold))
                        Text("v\(APP_VERSION)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // Browsers
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Browsers")

                        VStack(spacing: 0) {
                            ForEach(Array(configManager.installedBrowsers.enumerated()), id: \.element.id) { index, browser in
                                BrowserRowView(browser: browser)
                                if index < configManager.installedBrowsers.count - 1 {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Keyboard Shortcuts
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Keyboard Shortcuts")

                        VStack(spacing: 1) {
                            shortcutRow("Switch Tabs", shortcut: $configManager.shortcuts.tabSwitch)
                            Divider().padding(.horizontal, 12)
                            shortcutRow("Copy URL", shortcut: $configManager.shortcuts.copyUrl)
                        }
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("Reset to Defaults") {
                            configManager.shortcuts = .defaults
                            configManager.saveShortcuts()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.link)
                        .padding(.leading, 4)
                    }

                    // Extension update notice
                    if configManager.showExtensionUpdateInstructions {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12))
                                Text("Extension Update Available")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Button {
                                    configManager.showExtensionUpdateInstructions = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("1. Download the latest extension package")
                                Text("2. Unzip and replace the old extension folder")
                                Text("3. Open chrome://extensions")
                                Text("4. Click the reload icon on Tab Switcher")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Button("Download") {
                                    if let url = URL(string: "https://github.com/nechemyaspitz/tab-switcher/archive/refs/heads/master.zip") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                Button("Copy chrome://extensions") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("chrome://extensions", forType: .string)
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // Footer
            Divider()
            HStack {
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .font(.system(size: 12))
                .disabled(!updater.canCheckForUpdates)
                Spacer()
                Button("Done") {
                    configManager.showingSetup = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!configManager.browsers.contains { $0.isEnabled })
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 580)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .tracking(0.5)
            .padding(.leading, 4)
    }

    private func shortcutRow(_ label: String, shortcut: Binding<ShortcutConfig>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            ShortcutRecorderView(
                shortcut: shortcut,
                onChange: { configManager.saveShortcuts() }
            )
            .frame(width: 160, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Browser Row View

struct BrowserRowView: View {
    let browser: BrowserInfo
    @ObservedObject var configManager = BrowserConfigManager.shared
    @State private var isExpanded = false
    @State private var extensionId: String = ""

    private var currentBrowser: BrowserInfo? {
        configManager.browsers.first { $0.id == browser.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                    if isExpanded {
                        extensionId = currentBrowser?.extensionId ?? ""
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if let icon = browser.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 22))
                            .frame(width: 32, height: 32)
                            .foregroundColor(.secondary)
                    }

                    Text(browser.appName)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)

                    Spacer()

                    if currentBrowser?.isEnabled == true {
                        Text("Enabled")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded section
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().padding(.leading, 42)

                    if currentBrowser?.isEnabled == true {
                        // Enabled state — show settings + disable
                        if let current = currentBrowser {
                            Toggle(isOn: Binding(
                                get: { current.combineAllWindows },
                                set: { configManager.setCombineWindows(id: browser.id, combine: $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Cycle through all windows")
                                        .font(.system(size: 12))
                                    Text("When off, only tabs from the active window are shown")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }

                        Button("Disable Browser") {
                            configManager.disableBrowser(id: browser.id)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .buttonStyle(.plain)
                    } else {
                        // Not enabled — show extension ID input
                        Text("Paste the extension ID from \(browser.name)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Text("Extensions \u{2192} Developer Mode \u{2192} Copy ID")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))

                        HStack(spacing: 6) {
                            PastableTextField(text: $extensionId, placeholder: "32-character extension ID")
                                .frame(height: 22)
                            Button("Enable") {
                                if extensionId.count == 32 {
                                    configManager.enableBrowser(id: browser.id, extensionId: extensionId)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(extensionId.count != 32)
                        }

                        if !extensionId.isEmpty && extensionId.count != 32 {
                            Text("\(extensionId.count)/32 characters")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
        .onAppear {
            extensionId = currentBrowser?.extensionId ?? ""
        }
    }
}

// Custom NSTextField that properly handles paste
class PastableNSTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// AppKit TextField wrapper for proper paste support
struct PastableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeNSView(context: Context) -> PastableNSTextField {
        let textField = PastableNSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)
        textField.focusRingType = .exterior
        return textField
    }
    
    func updateNSView(_ nsView: PastableNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        
        init(text: Binding<String>) {
            self.text = text
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text.wrappedValue = textField.stringValue
            }
        }
    }
}

// BrowserRowView removed — replaced by BrowserTileView in SetupView

// MARK: - Tab Data Model

struct TabInfo: Identifiable {
    let id: Int
    let title: String
    let favIconUrl: String
    let thumbnail: NSImage?
    let url: String
}

// MARK: - Tab Switcher State

class TabSwitcherState: ObservableObject {
    static let shared = TabSwitcherState()
    
    @Published var isVisible = false
    @Published var tabs: [TabInfo] = []
    @Published var selectedIndex: Int = 0
    
    func showSwitcher(tabs: [TabInfo], selectedIndex: Int) {
        DispatchQueue.main.async {
            self.tabs = tabs
            self.selectedIndex = selectedIndex
            self.isVisible = true
        }
    }
    
    func updateSelection(index: Int) {
        DispatchQueue.main.async {
            self.selectedIndex = index
        }
    }
    
    func hideSwitcher() {
        DispatchQueue.main.async {
            self.isVisible = false
        }
    }
}

// MARK: - Toast Notification

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var isVisible = false
    @Published var isAnimatingOut = false
    @Published var message = ""
    @Published var detail = ""

    private var dismissTimer: DispatchWorkItem?
    private var animateOutTimer: DispatchWorkItem?

    func showToast(message: String, detail: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            self.dismissTimer?.cancel()
            self.animateOutTimer?.cancel()
            self.isAnimatingOut = false
            self.message = message
            self.detail = detail
            self.isVisible = true

            let timer = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.isAnimatingOut = true
                let hideTimer = DispatchWorkItem { [weak self] in
                    self?.isVisible = false
                    self?.isAnimatingOut = false
                }
                self.animateOutTimer = hideTimer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: hideTimer)
            }
            self.dismissTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: timer)
        }
    }
}

struct ToastView: View {
    @ObservedObject var toast = ToastManager.shared
    let toastWidth: CGFloat = 260

    var body: some View {
        if toast.isVisible {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.3, green: 0.85, blue: 0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(toast.message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(toast.detail)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .frame(width: toastWidth)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .opacity(toast.isAnimatingOut ? 0 : 1)
            .scaleEffect(toast.isAnimatingOut ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.25), value: toast.isAnimatingOut)
        }
    }
}

class ToastWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 54),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false

        let hostingView = NSHostingView(rootView: ToastView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Tab Card View

struct TabCardView: View {
    let tab: TabInfo
    let isSelected: Bool
    let cornerRadius: CGFloat = 10
    let cardWidth: CGFloat = 220
    let cardHeight: CGFloat = 146
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background layer - thumbnail or fallback
            Group {
                if let thumbnail = tab.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                } else {
                    // Fallback gradient with favicon
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Large favicon in center
                        AsyncFaviconView(url: tab.favIconUrl, size: 36)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            
            // Title overlay at top - always on top
            HStack(spacing: 5) {
                AsyncFaviconView(url: tab.favIconUrl, size: 12)
                
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.top, 5)
            .padding(.bottom, 10)
            .frame(width: cardWidth)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: isSelected ? 3 : 1)
        )
    }
}

// MARK: - Async Favicon View

struct AsyncFaviconView: View {
    let url: String
    let size: CGFloat
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear {
            loadFavicon()
        }
    }
    
    private func loadFavicon() {
        guard !url.isEmpty, let faviconURL = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
            if let data = data, let loadedImage = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }.resume()
    }
}

// MARK: - Tab Switcher View

struct TabSwitcherView: View {
    @ObservedObject var state = TabSwitcherState.shared
    let padding: CGFloat = 16
    let cardWidth: CGFloat = 220
    let cardSpacing: CGFloat = 12
    
    var body: some View {
        if state.isVisible && !state.tabs.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                            TabCardView(
                                tab: tab,
                                isSelected: index == state.selectedIndex
                            )
                            .id(index)
                        }
                    }
                    .padding(padding)
                }
                .onChange(of: state.selectedIndex) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(state.selectedIndex, anchor: .center)
                    }
                }
            }
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Visual Effect View (for blur background)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Get Browser Window Frame

func getBrowserWindowFrame() -> NSRect? {
    // First check if a supported browser is the frontmost app
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleId = frontApp.bundleIdentifier,
          BrowserConfigManager.shared.enabledBundleIds.contains(bundleId) else {
        debugLog("No supported browser is frontmost")
        return nil
    }
    
    // Get Chrome's windows using Accessibility API
    let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
    
    // Try to get the focused window first
    var focusedWindowRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
       let focusedWindow = focusedWindowRef {
        if let frame = getWindowFrame(focusedWindow as! AXUIElement) {
            return frame
        }
    }
    
    // Fall back to first window in the list
    var windowsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let windows = windowsRef as? [AXUIElement],
          let frontWindow = windows.first else {
        debugLog("Could not get Chrome windows")
        return nil
    }
    
    return getWindowFrame(frontWindow)
}

func getWindowFrame(_ window: AXUIElement) -> NSRect? {
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
          AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
          let posVal = positionRef,
          let sizeVal = sizeRef else {
        debugLog("Could not get window position/size")
        return nil
    }
    
    var position = CGPoint.zero
    var size = CGSize.zero
    
    guard AXValueGetValue(posVal as! AXValue, .cgPoint, &position),
          AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else {
        debugLog("Could not extract position/size values")
        return nil
    }
    
    // Sanity check - window should have reasonable size
    guard size.width > 100 && size.height > 100 else {
        debugLog("Window size too small: \(size)")
        return nil
    }
    
    // Convert from top-left origin (Accessibility) to bottom-left origin (NSWindow)
    // Need to find which screen the window is on
    var screenHeight: CGFloat = 0
    for screen in NSScreen.screens {
        if screen.frame.contains(CGPoint(x: position.x + size.width/2, y: position.y + size.height/2)) ||
           screen.frame.contains(position) {
            screenHeight = screen.frame.maxY
            break
        }
    }
    
    // If we couldn't find the screen, use main screen
    if screenHeight == 0 {
        screenHeight = NSScreen.main?.frame.maxY ?? 0
    }
    
    let convertedY = screenHeight - position.y - size.height
    
    debugLog("Chrome window: pos=(\(position.x), \(position.y)) size=\(size) convertedY=\(convertedY)")
    
    return NSRect(x: position.x, y: convertedY, width: size.width, height: size.height)
}

// MARK: - Floating Window

class TabSwitcherWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 128),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        
        let hostingView = NSHostingView(rootView: TabSwitcherView())
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: TabSwitcherWindow?
    var toastWindow: ToastWindow?
    var setupWindow: NSWindow?
    var cancellable: AnyCancellable?
    var toastCancellable: AnyCancellable?
    var setupCancellable: AnyCancellable?
    var launchedDirectly = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup application menu (for Cmd+Q support)
        if launchedDirectly {
            setupMainMenu()
        }
        debugLog("App delegate launched, launchedDirectly=\(launchedDirectly)")

        // Setup macOS system notifications for background update checking
        BackgroundUpdateChecker.shared.setupNotifications()
        
        // Create the floating window for tab switching UI
        window = TabSwitcherWindow()
        toastWindow = ToastWindow()
        debugLog("Window created")

        // Observe toast visibility
        toastCancellable = ToastManager.shared.$isVisible.sink { [weak self] isVisible in
            DispatchQueue.main.async {
                if isVisible {
                    let toastWidth: CGFloat = 290
                    let toastHeight: CGFloat = 54
                    let bottomMargin: CGFloat = 20
                    // Position bottom-center of browser window
                    if let chromeFrame = getBrowserWindowFrame() {
                        let x = chromeFrame.midX - toastWidth / 2
                        let y = chromeFrame.minY + bottomMargin
                        self?.toastWindow?.setContentSize(NSSize(width: toastWidth, height: toastHeight))
                        self?.toastWindow?.setFrameOrigin(NSPoint(x: x, y: y))
                    } else if let screen = NSScreen.main {
                        let x = screen.visibleFrame.midX - toastWidth / 2
                        let y = screen.visibleFrame.minY + bottomMargin
                        self?.toastWindow?.setContentSize(NSSize(width: toastWidth, height: toastHeight))
                        self?.toastWindow?.setFrameOrigin(NSPoint(x: x, y: y))
                    }
                    self?.toastWindow?.invalidateShadow()
                    self?.toastWindow?.orderFront(nil)
                } else {
                    self?.toastWindow?.orderOut(nil)
                }
            }
        }
        
        // Only show setup UI when launched directly (from Finder/Dock)
        // Native messaging launches should NEVER show UI or dock icon
        if launchedDirectly {
            debugLog("Direct launch - showing setup window")
            // Always set showingSetup to true for direct launches so the window stays open
            allowConfigUI = true
            BrowserConfigManager.shared.showingSetup = true
            showSetupWindow()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            debugLog("Running as accessory (native messaging mode)")
        }
        
        // Observe setup window state - but ONLY for direct launches
        setupCancellable = BrowserConfigManager.shared.$showingSetup
            .dropFirst() // Skip initial value to prevent immediate close
            .sink { [weak self] showing in
                guard let self = self else { return }
                
                // CRITICAL: Never process for native messaging instances unless user requested it
                if !self.launchedDirectly && !allowConfigUI {
                    return
                }
                
                DispatchQueue.main.async {
                    if showing {
                        NSApp.setActivationPolicy(.regular)
                        self.showSetupWindow()
                    } else {
                        self.setupWindow?.close()
                        self.setupWindow = nil
                        if !self.launchedDirectly {
                            // Return to background mode if this was only a temporary UI
                            NSApp.setActivationPolicy(.accessory)
                            allowConfigUI = false
                        }
                    }
                }
            }
        
        // Observe state changes to show/hide switcher window
        cancellable = TabSwitcherState.shared.$isVisible.sink { [weak self] isVisible in
            debugLog("Visibility changed to: \(isVisible)")
            DispatchQueue.main.async {
                if isVisible {
                    debugLog("Showing window with \(TabSwitcherState.shared.tabs.count) tabs")
                    
                    let tabCount = TabSwitcherState.shared.tabs.count
                    guard tabCount > 0 else { return }
                    
                    let cardWidth: CGFloat = 220
                    let cardSpacing: CGFloat = 12
                    let padding: CGFloat = 16
                    let cardHeight: CGFloat = 146
                    
                    // Calculate content width
                    let contentWidth = CGFloat(tabCount) * cardWidth + CGFloat(max(0, tabCount - 1)) * cardSpacing + padding * 2
                    let height: CGFloat = cardHeight + padding * 2
                    
                    // Get browser window frame
                    let chromeFrame = getBrowserWindowFrame()
                    
                    // Always get main screen as fallback
                    guard let mainScreen = NSScreen.main else { return }
                    
                    // Use browser frame if available and valid, otherwise use screen
                    let targetFrame: NSRect
                    if let frame = chromeFrame, 
                       frame.width > 200 && frame.height > 200,
                       frame.origin.x >= -10000 && frame.origin.y >= -10000 {
                        targetFrame = frame
                        debugLog("Using browser window frame: \(frame)")
                    } else {
                        targetFrame = mainScreen.visibleFrame
                        debugLog("Falling back to screen frame: \(targetFrame)")
                    }
                    
                    // Calculate width - fit within target, with max limit
                    let maxWidth = min(targetFrame.width - 40, 1200) // 20px margin on each side
                    let width = min(contentWidth, maxWidth)
                    
                    self?.window?.setContentSize(NSSize(width: width, height: height))
                    
                    // Center within target frame
                    let x = targetFrame.origin.x + (targetFrame.width - width) / 2
                    let y = targetFrame.origin.y + (targetFrame.height - height) / 2 + targetFrame.height * 0.08 // Slightly above center
                    
                    // Ensure position is valid
                    let finalX = max(0, x)
                    let finalY = max(0, y)
                    
                    self?.window?.setFrameOrigin(NSPoint(x: finalX, y: finalY))
                    self?.window?.orderFront(nil)
                    debugLog("Window positioned at (\(finalX), \(finalY)) with size \(width)x\(height)")
                } else {
                    debugLog("Hiding window")
                    self?.window?.orderOut(nil)
                }
            }
        }
    }
    
    func showSetupWindow() {
        if setupWindow == nil {
            let setupView = SetupView()
            setupWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 580),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            setupWindow?.title = "Tab Switcher"
            setupWindow?.titlebarAppearsTransparent = true
            setupWindow?.contentView = NSHostingView(rootView: setupView)
            setupWindow?.center()
            setupWindow?.isReleasedWhenClosed = false

            // Handle window close
            setupWindow?.delegate = self
        }
        
        // Ensure we can receive focus/menus even if we were running as a background app
        NSApp.setActivationPolicy(.regular)
        if NSApp.mainMenu == nil {
            setupMainMenu()
        }
        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSRunningApplication.current.activate()
    }
    
    func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Tab Switcher", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        checkForUpdatesItem.target = updaterViewModel.updaterController
        appMenu.addItem(checkForUpdatesItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Tab Switcher", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Tab Switcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == setupWindow {
            BrowserConfigManager.shared.showingSetup = false
        }
    }
}

extension AppDelegate {
    // Called when user clicks dock icon while app is running
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            allowConfigUI = true
            BrowserConfigManager.shared.showingSetup = true
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        debugLog("Application will terminate - cleaning up locks")
        cleanupEventTapLock()
        BackgroundUpdateChecker.shared.cleanupUpdateCheckLock()
    }
}

// MARK: - Debug Logging (to stderr, doesn't interfere with native messaging)

let DEBUG_LOGGING = true // Set to true for debugging
let DEBUG_LOG_FILE = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("tabswitcher_debug.log")

func debugLog(_ message: String) {
    if DEBUG_LOGGING {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] TabSwitch: \(message)\n"
        
        // Write to stderr
        FileHandle.standardError.write(logMessage.data(using: .utf8)!)
        
        // Also append to log file for debugging
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: DEBUG_LOG_FILE.path) {
                if let handle = try? FileHandle(forWritingTo: DEBUG_LOG_FILE) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: DEBUG_LOG_FILE)
            }
        }
    }
}

// MARK: - Native Messaging Protocol

func sendMessage(_ dict: [String: Any]) {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
        debugLog("Failed to serialize message")
        return
    }
    
    var length = UInt32(jsonData.count).littleEndian
    let lengthData = Data(bytes: &length, count: 4)
    
    FileHandle.standardOutput.write(lengthData)
    FileHandle.standardOutput.write(jsonData)
}

func sendAction(_ action: String) {
    sendMessage(["action": action])
}

func readMessage() -> [String: Any]? {
    let lengthData = FileHandle.standardInput.readData(ofLength: 4)
    guard lengthData.count == 4 else { 
        // Connection closed (EOF) - extension disconnected
        debugLog("Connection closed (EOF on stdin) - extension disconnected, exiting...")
        // Exit the app when the extension disconnects
        // This is critical for multi-profile support - prevents orphan processes
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
        return nil 
    }
    
    let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    guard length > 0 && length < 10 * 1024 * 1024 else { 
        debugLog("Invalid message length: \(length)")
        return nil 
    }
    
    let messageData = FileHandle.standardInput.readData(ofLength: Int(length))
    guard messageData.count == Int(length) else { 
        debugLog("Incomplete message data")
        return nil 
    }
    
    let result = try? JSONSerialization.jsonObject(with: messageData, options: []) as? [String: Any]
    if let action = result?["action"] as? String {
        debugLog("Received message: \(action)")
    }
    return result
}

// MARK: - Message Handler

func handleMessage(_ message: [String: Any]) {
    guard let action = message["action"] as? String else { 
        debugLog("Message has no action")
        return 
    }
    
    debugLog("Handling action: \(action)")
    
    switch action {
    case "show_switcher":
        if let tabsData = message["tabs"] as? [[String: Any]],
           let selectedIndex = message["selectedIndex"] as? Int {
            let tabs = tabsData.compactMap { parseTabInfo($0) }
            debugLog("Showing switcher with \(tabs.count) tabs, selected: \(selectedIndex)")
            TabSwitcherState.shared.showSwitcher(tabs: tabs, selectedIndex: selectedIndex)
        } else {
            debugLog("Invalid show_switcher data")
        }
        
    case "update_selection":
        if let selectedIndex = message["selectedIndex"] as? Int {
            debugLog("Updating selection to: \(selectedIndex)")
            TabSwitcherState.shared.updateSelection(index: selectedIndex)
        }
        
    case "hide_switcher":
        debugLog("Hiding switcher")
        TabSwitcherState.shared.hideSwitcher()
        
    case "register":
        // Extension tells us which browser it's running in
        // Only use this if we couldn't auto-detect, or if it matches a known browser
        if let extVersion = message["extensionVersion"] as? String {
            debugLog("Extension version: \(extVersion)")
            BackgroundUpdateChecker.shared.setExtensionVersion(extVersion)
        }
        if let bundleId = message["bundleId"] as? String {
            if ownerBrowserBundleId == nil {
                ownerBrowserBundleId = bundleId
                // Try to detect the PID now if we didn't before
                if ownerBrowserProcessId == nil {
                    if let (_, detectedPid) = detectParentBrowser() {
                        ownerBrowserProcessId = detectedPid
                        debugLog("Registered with browser (from extension): \(bundleId) with late-detected PID \(detectedPid)")
                    } else {
                        debugLog("Registered with browser (from extension): \(bundleId) but couldn't detect PID")
                    }
                } else {
                    debugLog("Registered with browser (from extension): \(bundleId)")
                }
            } else {
                debugLog("Already auto-detected browser: \(ownerBrowserBundleId!) (PID \(ownerBrowserProcessId ?? -1)), ignoring extension registration: \(bundleId)")
            }
            let shortcuts: [String: String] = [
                "tabSwitch": BrowserConfigManager.shared.shortcuts.tabSwitch.displayString,
                "copyUrl": BrowserConfigManager.shared.shortcuts.copyUrl.displayString
            ]
            sendMessage(["action": "registered", "bundleId": ownerBrowserBundleId ?? bundleId, "shortcuts": shortcuts])
        }
        
    case "ping":
        // Respond to ping to confirm connection is alive
        debugLog("Received ping, sending pong")
        sendMessage(["action": "pong"])

    case "url_copied":
        if let url = message["url"] as? String {
            debugLog("Received URL to copy: \(url)")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url, forType: .string)
            DispatchQueue.main.async {
                ToastManager.shared.showToast(message: "Copied!", detail: url)
            }
        }

    default:
        debugLog("Unknown action: \(action)")
    }
}

func parseTabInfo(_ dict: [String: Any]) -> TabInfo? {
    guard let id = dict["id"] as? Int,
          let title = dict["title"] as? String else {
        return nil
    }
    
    let favIconUrl = dict["favIconUrl"] as? String ?? ""
    let url = dict["url"] as? String ?? ""
    
    var thumbnail: NSImage? = nil
    if let thumbnailData = dict["thumbnail"] as? String,
       !thumbnailData.isEmpty,
       let dataUrl = thumbnailData.components(separatedBy: ",").last,
       let imageData = Data(base64Encoded: dataUrl) {
        thumbnail = NSImage(data: imageData)
    }
    
    return TabInfo(id: id, title: title, favIconUrl: favIconUrl, thumbnail: thumbnail, url: url)
}

// MARK: - Browser Detection

func isSupportedBrowserActive() -> Bool {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleId = frontApp.bundleIdentifier else {
        return false
    }
    
    // If we're registered with a specific browser process, only respond to that exact process
    // This is critical for multi-profile support - each Chrome profile is a separate process
    if let ownerBundle = ownerBrowserBundleId, let ownerPid = ownerBrowserProcessId {
        // Check both bundle ID AND process ID match
        let bundleMatches = bundleId == ownerBundle
        let pidMatches = frontApp.processIdentifier == ownerPid
        
        debugLog("Browser check: frontmost=\(bundleId) (PID \(frontApp.processIdentifier)), owner=\(ownerBundle) (PID \(ownerPid)), bundleMatch=\(bundleMatches), pidMatch=\(pidMatches)")
        
        // Only respond if this is the exact same browser process that spawned us
        return bundleMatches && pidMatches
    }
    
    // Fallback: if we only have bundle ID (e.g., from extension registration)
    if let ownerBundle = ownerBrowserBundleId {
        let isOwner = bundleId == ownerBundle
        debugLog("Browser check (bundle only): frontmost=\(bundleId), owner=\(ownerBundle), match=\(isOwner)")
        return isOwner
    }
    
    // If launched directly (for config UI), respond to any enabled browser
    if isatty(STDIN_FILENO) != 0 {
        return BrowserConfigManager.shared.enabledBundleIds.contains(bundleId)
    }
    
    // If launched via native messaging but no owner detected, DON'T respond
    // This prevents multiple native hosts from all responding
    debugLog("No owner browser set, not responding to events")
    return false
}

// Get bundle ID of active browser (for window frame detection)
func getActiveBrowserBundleId() -> String? {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleId = frontApp.bundleIdentifier else {
        return nil
    }
    
    // If registered, only return if it's our owner browser process
    if let ownerBundle = ownerBrowserBundleId, let ownerPid = ownerBrowserProcessId {
        // Check both bundle ID AND process ID match
        return (bundleId == ownerBundle && frontApp.processIdentifier == ownerPid) ? bundleId : nil
    }
    
    // Fallback: if we only have bundle ID
    if let ownerBundle = ownerBrowserBundleId {
        return bundleId == ownerBundle ? bundleId : nil
    }
    
    // If launched directly, allow any enabled browser
    if isatty(STDIN_FILENO) != 0 {
        guard BrowserConfigManager.shared.enabledBundleIds.contains(bundleId) else {
            return nil
        }
        return bundleId
    }
    
    return nil
}

// MARK: - Global State

var switchModifierIsPressed = false
var switchInProgress = false
var tabPressCount = 0
var ownerBrowserBundleId: String? = nil  // The browser that launched this native host instance
var ownerBrowserProcessId: pid_t? = nil  // The PID of the specific browser process that launched us
var myProcessId: pid_t = getpid()  // This native host's PID for identification
var isEventTapLeader = false  // Whether this instance owns the event tap
var allowConfigUI = false  // Allow showing config UI even if not direct launch

// Detect which browser launched this native host by checking parent process
// Returns (bundleId, processId) tuple
func detectParentBrowser() -> (String, pid_t)? {
    var currentPid = getppid()
    debugLog("Starting parent detection from PID: \(currentPid)")
    
    // Walk up the process tree looking for a known browser
    for level in 0..<10 {  // Check up to 10 levels
        // Try to get bundle ID via NSRunningApplication
        if let app = NSRunningApplication(processIdentifier: currentPid),
           let bundleId = app.bundleIdentifier {
            debugLog("Level \(level): PID \(currentPid) = \(bundleId)")
            
            // Check if this is a known browser
            if BrowserConfigManager.shared.enabledBundleIds.contains(bundleId) {
                debugLog("Found browser at level \(level): \(bundleId) with PID \(currentPid)")
                return (bundleId, currentPid)
            }
            
            // Check for browser helper processes by bundle ID patterns
            // Chrome variants: match the most specific first
            if bundleId.hasPrefix("com.google.Chrome.canary") {
                debugLog("Found Chrome Canary helper process with PID \(currentPid)")
                return ("com.google.Chrome.canary", currentPid)
            }
            if bundleId.hasPrefix("com.google.Chrome.dev") {
                debugLog("Found Chrome Dev helper process with PID \(currentPid)")
                return ("com.google.Chrome.dev", currentPid)
            }
            if bundleId.contains("Chrome") || app.localizedName?.contains("Chrome") == true {
                debugLog("Found Chrome-related process, assuming com.google.Chrome with PID \(currentPid)")
                return ("com.google.Chrome", currentPid)
            }
            if bundleId.contains("Helium") || bundleId.contains("imput") {
                debugLog("Found Helium-related process with PID \(currentPid)")
                return ("net.imput.helium", currentPid)
            }
            if bundleId.contains("Brave") {
                return ("com.brave.Browser", currentPid)
            }
            if bundleId.contains("Edge") {
                return ("com.microsoft.edgemac", currentPid)
            }
            if bundleId.contains("Thorium") || bundleId.contains("org.chromium.Thorium") {
                return ("org.chromium.Thorium", currentPid)
            }
            if bundleId.contains("perplexity") || bundleId.contains("comet") {
                return ("ai.perplexity.comet", currentPid)
            }
            if bundleId.contains("openai") || bundleId.contains("atlas") {
                return ("com.openai.atlas", currentPid)
            }
        }
        
        // Get parent of current process using sysctl
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        
        if sysctl(&mib, 4, &info, &size, nil, 0) == 0 {
            let nextParent = info.kp_eproc.e_ppid
            debugLog("Level \(level): PID \(currentPid) parent is \(nextParent)")
            
            if nextParent == currentPid || nextParent <= 1 {
                break
            }
            currentPid = nextParent
        } else {
            debugLog("sysctl failed at level \(level)")
            break
        }
    }
    
    debugLog("Could not detect parent browser after walking tree")
    return nil
}
var showUITimer: DispatchWorkItem? = nil
let showUIDelay: Double = 0.15 // 150ms delay before showing UI

// Lock file for event tap coordination - only one native host should have the event tap
let eventTapLockFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tabswitcher_eventtap.lock")

// Check if we should be the event tap leader (first one to claim the lock)
func tryBecomeEventTapLeader() -> Bool {
    let myPid = getpid()
    
    // Check if lock file exists
    if FileManager.default.fileExists(atPath: eventTapLockFile.path) {
        // Read existing PID
        if let contents = try? String(contentsOf: eventTapLockFile, encoding: .utf8),
           let existingPid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // Check if that process is still running AND is actually Tab Switcher
            if kill(existingPid, 0) == 0 {
                // Process exists, but verify it's actually Tab Switcher
                if let app = NSRunningApplication(processIdentifier: existingPid),
                   app.bundleIdentifier == Bundle.main.bundleIdentifier {
                    // It's actually our app - we're not the leader
                    debugLog("Another Tab Switcher instance (PID \(existingPid)) owns the event tap, we (PID \(myPid)) will listen only")
                    return false
                } else {
                    // PID exists but it's not Tab Switcher - stale lock file
                    debugLog("Lock file has PID \(existingPid) but it's not Tab Switcher - removing stale lock")
                    try? FileManager.default.removeItem(at: eventTapLockFile)
                }
            } else {
                // Process doesn't exist - stale lock file
                debugLog("Lock file has dead PID \(existingPid) - removing stale lock")
                try? FileManager.default.removeItem(at: eventTapLockFile)
            }
        } else {
            // Couldn't read PID from lock file - remove it
            debugLog("Lock file exists but couldn't read PID - removing")
            try? FileManager.default.removeItem(at: eventTapLockFile)
        }
    }
    
    // Claim the lock
    do {
        try String(myPid).write(to: eventTapLockFile, atomically: true, encoding: .utf8)
        debugLog("We (PID \(myPid)) are now the event tap leader")
        return true
    } catch {
        debugLog("Failed to write lock file: \(error)")
        return false
    }
}

// Clean up lock file on exit and notify listeners to take over
func cleanupEventTapLock() {
    if isEventTapLeader {
        try? FileManager.default.removeItem(at: eventTapLockFile)
        debugLog("Cleaned up event tap lock file")
        
        // Notify other instances that the leader has resigned
        // They should try to become the new leader
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(leaderResignedNotificationName),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        debugLog("Posted leader-resigned notification")
    }
}

// Distributed notification names for IPC between native hosts
let ctrlTabNotificationName = "com.tabswitcher.ctrlTab"
let ctrlReleaseNotificationName = "com.tabswitcher.ctrlRelease"
let leaderResignedNotificationName = "com.tabswitcher.leaderResigned"
let showConfigNotificationName = "com.tabswitcher.showConfig"
let copyUrlNotificationName = "com.tabswitcher.copyUrl"
let shortcutsChangedNotificationName = "com.tabswitcher.shortcutsChanged"

// Setup listener for distributed notifications (for non-leader hosts)
func setupNotificationListener() {
    let center = DistributedNotificationCenter.default()
    
    center.addObserver(forName: NSNotification.Name(ctrlTabNotificationName), object: nil, queue: .main) { notification in
        guard let userInfo = notification.userInfo,
              let direction = userInfo["direction"] as? String,
              let showUI = userInfo["showUI"] as? Bool,
              let combineWindows = userInfo["combineWindows"] as? Bool,
              let targetBrowser = userInfo["targetBrowser"] as? String else {
            return
        }
        
        // Only respond if this notification is for OUR browser
        guard let myBrowser = ownerBrowserBundleId, myBrowser == targetBrowser else {
            debugLog("Ignoring ctrl-tab notification - target=\(targetBrowser), we are=\(ownerBrowserBundleId ?? "unknown")")
            return
        }
        
        debugLog("Received ctrl-tab notification for our browser: direction=\(direction), showUI=\(showUI)")
        
        // Send to our extension
        sendMessage([
            "action": direction,
            "show_ui": showUI,
            "current_window_only": !combineWindows
        ])
    }
    
    center.addObserver(forName: NSNotification.Name(ctrlReleaseNotificationName), object: nil, queue: .main) { notification in
        // Only respond if this is for our browser
        if let userInfo = notification.userInfo,
           let targetBrowser = userInfo["targetBrowser"] as? String {
            guard let myBrowser = ownerBrowserBundleId, myBrowser == targetBrowser else {
                return
            }
        }
        
        debugLog("Received ctrl-release notification")
        sendAction("end_switch")
    }
    
    center.addObserver(forName: NSNotification.Name("com.tabswitcher.requestShowUI"), object: nil, queue: .main) { notification in
        guard let userInfo = notification.userInfo,
              let combineWindows = userInfo["combineWindows"] as? Bool else {
            return
        }
        
        // Only respond if this is for our browser
        if let targetBrowser = userInfo["targetBrowser"] as? String {
            guard let myBrowser = ownerBrowserBundleId, myBrowser == targetBrowser else {
                return
            }
        }
        
        debugLog("Received request-show-ui notification")
        sendMessage(["action": "request_show_ui", "current_window_only": !combineWindows])
    }
    
    // Listen for leader resignation - try to become the new leader
    center.addObserver(forName: NSNotification.Name(leaderResignedNotificationName), object: nil, queue: .main) { _ in
        debugLog("Received leader-resigned notification")
        
        // If we're not already the leader, try to become one
        if !isEventTapLeader {
            // Small delay to let the old leader fully exit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if tryBecomeEventTapLeader() {
                    isEventTapLeader = true
                    if setupEventTap() {
                        debugLog("Successfully became new event tap leader after resignation")
                    } else {
                        debugLog("Failed to setup event tap after becoming leader")
                    }
                }
            }
        }
    }
    
    // Listen for show-config request (from directly-launched app trying to show UI)
    center.addObserver(forName: NSNotification.Name(showConfigNotificationName), object: nil, queue: .main) { _ in
        debugLog("Received show-config notification")
        // Show the config window if we have one
        DispatchQueue.main.async {
            allowConfigUI = true
            BrowserConfigManager.shared.showingSetup = true
        }
    }
    
    // Listen for copy-URL request
    center.addObserver(forName: NSNotification.Name(copyUrlNotificationName), object: nil, queue: .main) { notification in
        guard let userInfo = notification.userInfo,
              let targetBrowser = userInfo["targetBrowser"] as? String else { return }
        guard let myBrowser = ownerBrowserBundleId, myBrowser == targetBrowser else {
            debugLog("Ignoring copy-url notification - not our browser")
            return
        }
        debugLog("Received copy-url notification for our browser")
        sendMessage(["action": "copy_url"])
    }

    // Listen for shortcut config changes from other instances
    center.addObserver(forName: NSNotification.Name(shortcutsChangedNotificationName), object: nil, queue: .main) { _ in
        debugLog("Received shortcuts-changed notification, reloading")
        BrowserConfigManager.shared.loadShortcuts()
    }

    // Listen for app update trigger (from notification click)
    center.addObserver(forName: NSNotification.Name("com.tabswitcher.triggerAppUpdate"), object: nil, queue: .main) { _ in
        debugLog("Received triggerAppUpdate notification")
        if let delegate = NSApp.delegate as? AppDelegate, delegate.launchedDirectly {
            allowConfigUI = true
            BrowserConfigManager.shared.showingSetup = true
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updaterViewModel.checkForUpdates()
            }
        }
    }

    // Listen for extension update display request (from notification click)
    center.addObserver(forName: NSNotification.Name("com.tabswitcher.showExtensionUpdate"), object: nil, queue: .main) { _ in
        debugLog("Received showExtensionUpdate notification")
        DispatchQueue.main.async {
            allowConfigUI = true
            BrowserConfigManager.shared.showingSetup = true
            BrowserConfigManager.shared.showExtensionUpdateInstructions = true
        }
    }

    // Listen for update checker leader resignation
    center.addObserver(forName: NSNotification.Name("com.tabswitcher.updateCheckerResigned"), object: nil, queue: .main) { _ in
        debugLog("Update checker leader resigned, attempting to take over")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            BackgroundUpdateChecker.shared.tryTakeOverLeadership()
        }
    }

    debugLog("Notification listener setup complete (PID \(myProcessId), browser=\(ownerBrowserBundleId ?? "unknown"))")
    
    // Periodic check for dead leader (backup in case leader crashes without notification)
    // Only do this for non-leaders that were launched via native messaging
    if !isEventTapLeader {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Check if the current leader is still alive
            if FileManager.default.fileExists(atPath: eventTapLockFile.path) {
                if let contents = try? String(contentsOf: eventTapLockFile, encoding: .utf8),
                   let leaderPid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    // Check if leader is still running
                    if kill(leaderPid, 0) != 0 {
                        debugLog("Detected dead leader (PID \(leaderPid)), attempting to take over")
                        if tryBecomeEventTapLeader() {
                            isEventTapLeader = true
                            if setupEventTap() {
                                debugLog("Successfully became event tap leader after detecting dead leader")
                            }
                        }
                    }
                }
            } else {
                // No lock file exists, try to become leader
                debugLog("No lock file exists, attempting to become leader")
                if tryBecomeEventTapLeader() {
                    isEventTapLeader = true
                    if setupEventTap() {
                        debugLog("Successfully became event tap leader (no previous lock file)")
                    }
                }
            }
        }
    }
}

// Get the frontmost browser's bundle ID - check against ALL known browsers, not just enabled ones
func getFrontmostBrowserBundleId() -> String? {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleId = frontApp.bundleIdentifier else {
        return nil
    }
    
    // Check if this is any known Chromium browser (not just enabled ones)
    // This allows the event tap to work even before setup is complete
    let allKnownBrowserIds = Set(knownBrowsers.map { $0.id })
    if allKnownBrowserIds.contains(bundleId) {
        return bundleId
    }
    
    return nil
}

// Post notification to all native hosts - includes frontmost browser so only that browser responds
func postCtrlTabNotification(direction: String, showUI: Bool, combineWindows: Bool) {
    guard let frontmostBrowser = getFrontmostBrowserBundleId() else { return }
    
    let center = DistributedNotificationCenter.default()
    center.postNotificationName(
        NSNotification.Name(ctrlTabNotificationName),
        object: nil,
        userInfo: [
            "direction": direction,
            "showUI": showUI,
            "combineWindows": combineWindows,
            "targetBrowser": frontmostBrowser
        ],
        deliverImmediately: true
    )
    debugLog("Posted ctrl-tab notification for browser: \(frontmostBrowser)")
}

func postCtrlReleaseNotification() {
    guard let frontmostBrowser = getFrontmostBrowserBundleId() else { return }
    
    let center = DistributedNotificationCenter.default()
    center.postNotificationName(
        NSNotification.Name(ctrlReleaseNotificationName),
        object: nil,
        userInfo: ["targetBrowser": frontmostBrowser],
        deliverImmediately: true
    )
}

func postRequestShowUINotification(combineWindows: Bool) {
    guard let frontmostBrowser = getFrontmostBrowserBundleId() else { return }
    
    let center = DistributedNotificationCenter.default()
    center.postNotificationName(
        NSNotification.Name("com.tabswitcher.requestShowUI"),
        object: nil,
        userInfo: ["combineWindows": combineWindows, "targetBrowser": frontmostBrowser],
        deliverImmediately: true
    )
}

func postCopyUrlNotification() {
    guard let frontmostBrowser = getFrontmostBrowserBundleId() else { return }

    let center = DistributedNotificationCenter.default()
    center.postNotificationName(
        NSNotification.Name(copyUrlNotificationName),
        object: nil,
        userInfo: ["targetBrowser": frontmostBrowser],
        deliverImmediately: true
    )
    debugLog("Posted copy-url notification for browser: \(frontmostBrowser)")
}

// MARK: - Event Tap Callback

func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    // Handle tap disabled
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let tapRef = Unmanaged<AnyObject>.fromOpaque(refcon).takeUnretainedValue() as! CFMachPort
            CGEvent.tapEnable(tap: tapRef, enable: true)
        }
        return Unmanaged.passRetained(event)
    }
    
    // Only process when a supported browser is active
    // Check against ALL known browsers (not just enabled ones) so it works before setup
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleId = frontApp.bundleIdentifier else {
        return Unmanaged.passRetained(event)
    }
    
    let allKnownBrowserIds = Set(knownBrowsers.map { $0.id })
    guard allKnownBrowserIds.contains(bundleId) else {
        return Unmanaged.passRetained(event)
    }
    
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    // Mask to only modifier bits for matching
    let modifierMask: UInt64 = CGEventFlags([.maskControl, .maskShift, .maskCommand, .maskAlternate]).rawValue
    let currentMods = flags.rawValue & modifierMask

    // Determine the primary modifier for the tab-switch shortcut (for release detection)
    // Use the configured modifiers minus Shift (Shift is used for direction)
    let switchModFlag = CGEventFlags(rawValue: tabSwitchModifiers & modifierMask & ~CGEventFlags.maskShift.rawValue)

    // Handle flags changed (modifier key state changes)
    if type == .flagsChanged {
        let modifierNowPressed = !switchModFlag.isEmpty && flags.contains(switchModFlag)

        // Detect switch modifier release
        if switchModifierIsPressed && !modifierNowPressed && switchInProgress {
            showUITimer?.cancel()
            showUITimer = nil
            postCtrlReleaseNotification()
            switchInProgress = false
            tabPressCount = 0
        }

        switchModifierIsPressed = modifierNowPressed
        return Unmanaged.passRetained(event)
    }

    // Handle key down events
    if type == .keyDown {
        // Check for tab-switch shortcut (Shift excluded from base match — it toggles direction)
        let baseMods = tabSwitchModifiers & modifierMask & ~CGEventFlags.maskShift.rawValue
        let currentBase = currentMods & ~CGEventFlags.maskShift.rawValue
        if keyCode == tabSwitchKeyCode && currentBase == baseMods {
            if !switchInProgress {
                switchInProgress = true
                tabPressCount = 0
            }
            switchModifierIsPressed = true
            tabPressCount += 1

            let direction = (currentMods & CGEventFlags.maskShift.rawValue != 0) ? "cycle_prev" : "cycle_next"
            let combineWindows = false

            debugLog("Broadcasting tab switch: direction=\(direction), tabPressCount=\(tabPressCount)")

            if tabPressCount == 1 {
                postCtrlTabNotification(direction: direction, showUI: false, combineWindows: combineWindows)
                showUITimer?.cancel()
                let timer = DispatchWorkItem {
                    postRequestShowUINotification(combineWindows: combineWindows)
                }
                showUITimer = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + showUIDelay, execute: timer)
            } else {
                showUITimer?.cancel()
                showUITimer = nil
                postCtrlTabNotification(direction: direction, showUI: true, combineWindows: combineWindows)
            }

            return nil
        }

        // Check for copy-URL shortcut
        let copyMods = copyUrlModifiers & modifierMask
        if keyCode == copyUrlKeyCode && currentMods == copyMods {
            debugLog("Copy URL shortcut detected")
            postCopyUrlNotification()
            return nil
        }
    }

    return Unmanaged.passRetained(event)
}

// MARK: - Setup Event Tap

func setupEventTap() -> Bool {
    let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                  (1 << CGEventType.flagsChanged.rawValue)
    
    guard let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: eventTapCallback,
        userInfo: nil
    ) else {
        sendAction("error_no_accessibility")
        return false
    }
    
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
    return true
}

// MARK: - Message Reading Thread

func startMessageReader() {
    debugLog("Starting message reader thread")
    DispatchQueue.global(qos: .userInitiated).async {
        while true {
            if let message = readMessage() {
                handleMessage(message)
            } else {
                // Short sleep to prevent busy waiting
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
    }
}

// MARK: - Main

import Combine

// Check if launched directly (from Finder/Dock) or via native messaging (from browser)
func isLaunchedDirectly() -> Bool {
    // If Chrome launches via native messaging, it passes the extension URL as an argument
    // Example: chrome-extension://<id>/
    let args = ProcessInfo.processInfo.arguments
    if args.contains(where: { $0.hasPrefix("chrome-extension://") }) {
        debugLog("Detected chrome-extension:// arg - launched via native messaging")
        return false
    }
    
    // Check if parent process is launchd (PID 1) - means launched from Finder/Spotlight/Dock
    let parentPid = getppid()
    if parentPid == 1 {
        debugLog("Parent PID is 1 (launchd) - launched directly")
        return true
    }
    
    // Check if stdin is a pipe (native messaging) vs /dev/null or TTY (direct launch)
    var statInfo = stat()
    if fstat(STDIN_FILENO, &statInfo) == 0 {
        // S_IFIFO means it's a pipe (native messaging from browser)
        let mode = statInfo.st_mode & S_IFMT
        let isPipe = mode == S_IFIFO
        debugLog("stdin mode: \(mode), isPipe: \(isPipe)")
        if isPipe {
            return false  // Launched via native messaging
        }
    }
    
    // Fallback to isatty check
    let isTTY = isatty(STDIN_FILENO) != 0
    debugLog("isatty check: \(isTTY)")
    return true  // If not a pipe, assume direct launch
}

// Check if another instance of the app is already running (for direct launch only)
func isAnotherInstanceRunning() -> Bool {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let runningApps = NSWorkspace.shared.runningApplications
    
    // Look for other Tab Switcher instances (any activation policy)
    for app in runningApps {
        if app.bundleIdentifier == Bundle.main.bundleIdentifier,
           app.processIdentifier != currentPID {
            return true
        }
    }
    return false
}

// Tell existing instances to show their config window
func notifyExistingInstancesToShowConfig() {
    debugLog("Notifying existing instances to show config")
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name(showConfigNotificationName),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

// Check if accessibility permission is granted, optionally prompting the user
func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
    if prompt {
        // This will trigger the system permission prompt if not already granted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        debugLog("Accessibility check with prompt: \(trusted)")
        return trusted
    } else {
        let trusted = AXIsProcessTrusted()
        debugLog("Accessibility check (no prompt): \(trusted)")
        return trusted
    }
}

// Show accessibility permission alert
func showAccessibilityAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Tab Switcher needs Accessibility permission to intercept Ctrl+Tab.\n\nClick 'Open System Settings' to grant permission, then relaunch the app."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Continue Anyway")
    alert.addButton(withTitle: "Quit")
    
    let response = alert.runModal()
    
    switch response {
    case .alertFirstButtonReturn:
        // Open Accessibility settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        exit(0)
    case .alertSecondButtonReturn:
        // Continue without event tap (config only)
        break
    default:
        exit(0)
    }
}

// Main entry point
func main() {
    debugLog("Tab Switcher Native Host starting (PID \(myProcessId))...")
    
    let directLaunch = isLaunchedDirectly()
    debugLog("Launched directly: \(directLaunch)")
    
    // For direct launches, check if another DIRECTLY-LAUNCHED instance is already running
    // (Native messaging hosts don't count - they can't show config windows)
    if directLaunch {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        var directlyLaunchedInstanceExists = false
        
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == Bundle.main.bundleIdentifier,
               app.processIdentifier != currentPID,
               app.activationPolicy == .regular {  // Only count apps showing in dock
                directlyLaunchedInstanceExists = true
                break
            }
        }
        
        if directlyLaunchedInstanceExists {
            // Another directly-launched instance exists, activate it and exit
            debugLog("Another directly-launched instance exists, activating it")
            for app in NSWorkspace.shared.runningApplications {
                if app.bundleIdentifier == Bundle.main.bundleIdentifier,
                   app.activationPolicy == .regular {
                    app.activate(options: [])
                    break
                }
            }
            exit(0)
        }
        
        // No directly-launched instance, so we'll show the config
        // (There might be native messaging hosts running, but they can't show config)
        debugLog("No directly-launched instance found, we will show config")
        
        // Proactively check/request accessibility permission when launched directly
        // This triggers the system permission prompt if not already granted
        let hasAccessibility = checkAccessibilityPermission(prompt: true)
        debugLog("Accessibility permission: \(hasAccessibility)")
    }
    
    // Try to become the event tap leader (only one native host should have the event tap)
    isEventTapLeader = tryBecomeEventTapLeader()
    
    // Setup cleanup on exit using signal handlers
    signal(SIGTERM) { _ in
        cleanupEventTapLock()
        BackgroundUpdateChecker.shared.cleanupUpdateCheckLock()
        exit(0)
    }
    signal(SIGINT) { _ in
        cleanupEventTapLock()
        BackgroundUpdateChecker.shared.cleanupUpdateCheckLock()
        exit(0)
    }
    
    // Only setup event tap if we're the leader
    var eventTapSuccess = false
    if isEventTapLeader {
        eventTapSuccess = setupEventTap()
        if !eventTapSuccess {
            debugLog("Failed to setup event tap - likely missing accessibility permission")
        } else {
            debugLog("Event tap setup complete (we are the leader)")
        }
    } else {
        debugLog("Not the event tap leader, will listen for notifications only")
    }
    
    // Setup notification listener for receiving broadcasts from the leader
    setupNotificationListener()
    
    // Only start message reader if launched via native messaging
    if !directLaunch {
        // Detect which browser launched us BEFORE anything else
        // We need both bundle ID and process ID to correctly handle multiple profiles
        if let (detectedBundleId, detectedPid) = detectParentBrowser() {
            ownerBrowserBundleId = detectedBundleId
            ownerBrowserProcessId = detectedPid
            debugLog("Auto-detected owner browser: \(detectedBundleId) with PID \(detectedPid)")
        } else {
            debugLog("WARNING: Could not auto-detect browser, will wait for registration")
        }
        
        startMessageReader()
        sendAction("ready")
        debugLog("Ready message sent")
    }
    
    // Setup and run the application
    let app = NSApplication.shared
    let delegate = AppDelegate()
    delegate.launchedDirectly = directLaunch
    app.delegate = delegate
    
    if directLaunch {
        // Show in dock when launched directly
        app.setActivationPolicy(.regular)
    } else {
        // Run as background app when launched via native messaging
        app.setActivationPolicy(.accessory)
    }
    
    // Start Sparkle updater only when launched from Finder/Dock
    if directLaunch {
        updaterViewModel.startUpdater()
        BackgroundUpdateChecker.shared.skipAppUpdateNotifications = true
    }

    // Start background update checker (leader election ensures only one instance checks)
    BackgroundUpdateChecker.shared.startPeriodicChecks()

    debugLog("Starting NSApplication run loop")
    app.run()
}

main()
