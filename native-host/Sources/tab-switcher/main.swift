import Foundation
import AppKit
import SwiftUI
import Carbon.HIToolbox
import ApplicationServices

let APP_VERSION = "3.1"

// MARK: - Browser Configuration

struct BrowserInfo: Identifiable, Codable {
    let id: String // bundle identifier
    let name: String
    let nativeMessagingPath: String // relative to ~/Library/Application Support/
    var extensionId: String? // user-provided extension ID
    var isEnabled: Bool
    var combineAllWindows: Bool = false // false = only current window tabs, true = all windows
    
    var fullNativeMessagingPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/\(nativeMessagingPath)"
    }
    
    // Check if browser is installed
    var isInstalled: Bool {
        // Check common locations
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
    
    var appName: String {
        // Map bundle ID to app name
        switch id {
        case "com.google.Chrome": return "Google Chrome"
        case "com.brave.Browser": return "Brave Browser"
        case "com.microsoft.edgemac": return "Microsoft Edge"
        case "company.thebrowser.Browser": return "Arc"
        case "com.vivaldi.Vivaldi": return "Vivaldi"
        case "com.operasoftware.Opera": return "Opera"
        case "com.operasoftware.OperaGX": return "Opera GX"
        case "org.chromium.Chromium": return "Chromium"
        case "com.nicklockwood.Sidekick": return "Sidekick"
        case "ru.nicklockwood.Yandex": return "Yandex Browser"
        case "net.imput.helium": return "Helium"
        default: return name
        }
    }
    
    var icon: NSImage? {
        guard let path = appPath else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
}

// Known Chromium-based browsers
let knownBrowsers: [BrowserInfo] = [
    BrowserInfo(id: "com.google.Chrome", name: "Google Chrome",
                nativeMessagingPath: "Google/Chrome/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "com.brave.Browser", name: "Brave",
                nativeMessagingPath: "BraveSoftware/Brave-Browser/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "com.microsoft.edgemac", name: "Microsoft Edge",
                nativeMessagingPath: "Microsoft Edge/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "company.thebrowser.Browser", name: "Arc",
                nativeMessagingPath: "Arc/User Data/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "com.vivaldi.Vivaldi", name: "Vivaldi",
                nativeMessagingPath: "Vivaldi/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "com.operasoftware.Opera", name: "Opera",
                nativeMessagingPath: "com.operasoftware.Opera/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "com.operasoftware.OperaGX", name: "Opera GX",
                nativeMessagingPath: "com.operasoftware.OperaGX/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "org.chromium.Chromium", name: "Chromium",
                nativeMessagingPath: "Chromium/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
    BrowserInfo(id: "net.imput.helium", name: "Helium",
                nativeMessagingPath: "net.imput.helium/NativeMessagingHosts",
                extensionId: nil, isEnabled: false),
]

// MARK: - Browser Configuration Manager

class BrowserConfigManager: ObservableObject {
    static let shared = BrowserConfigManager()
    
    @Published var browsers: [BrowserInfo] = []
    @Published var showingSetup = false
    
    private let configURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("TabSwitcher")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("browsers.json")
    }()
    
    init() {
        loadConfig()
    }
    
    func loadConfig() {
        // Start with known browsers
        var loadedBrowsers = knownBrowsers
        
        // Try to load saved config
        if let data = try? Data(contentsOf: configURL),
           let saved = try? JSONDecoder().decode([BrowserInfo].self, from: data) {
            // Merge saved config with known browsers
            for (index, browser) in loadedBrowsers.enumerated() {
                if let savedBrowser = saved.first(where: { $0.id == browser.id }) {
                    loadedBrowsers[index].extensionId = savedBrowser.extensionId
                    loadedBrowsers[index].isEnabled = savedBrowser.isEnabled
                    loadedBrowsers[index].combineAllWindows = savedBrowser.combineAllWindows
                }
            }
        }
        
        browsers = loadedBrowsers
        
        // NOTE: Don't automatically show setup here - it's handled by AppDelegate
        // based on whether we're launched directly or via native messaging
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

// MARK: - Update Checker

struct VersionInfo: Codable {
    struct AppInfo: Codable {
        let version: String
        let downloadUrl: String
        let releaseNotes: String?
    }
    struct ExtensionInfo: Codable {
        let version: String
        let chromeWebStoreUrl: String?
        let releaseNotes: String?
    }
    let app: AppInfo
    let ext: ExtensionInfo?

    enum CodingKeys: String, CodingKey {
        case app
        case ext = "extension"
    }
}

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadUrl: String?
    @Published var releaseNotes: String?
    @Published var updateDismissed = false

    private let versionURL = URL(string: "https://tabswitcher.app/version.json")!
    private var timer: Timer?

    func startChecking() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        debugLog("Checking for app updates...")
        URLSession.shared.dataTask(with: versionURL) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                debugLog("Update check failed: \(error?.localizedDescription ?? "no data")")
                return
            }
            do {
                let info = try JSONDecoder().decode(VersionInfo.self, from: data)
                let latest = info.app.version
                let hasUpdate = self.compareVersions(APP_VERSION, latest) < 0
                DispatchQueue.main.async {
                    self.latestVersion = latest
                    self.downloadUrl = info.app.downloadUrl
                    self.releaseNotes = info.app.releaseNotes
                    self.updateAvailable = hasUpdate
                    if hasUpdate {
                        self.updateDismissed = false
                    }
                    debugLog("App update check: current=\(APP_VERSION), latest=\(latest), updateAvailable=\(hasUpdate)")
                }
            } catch {
                debugLog("Failed to decode version.json: \(error)")
            }
        }.resume()
    }

    private func compareVersions(_ a: String, _ b: String) -> Int {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)
        for i in 0..<count {
            let numA = i < partsA.count ? partsA[i] : 0
            let numB = i < partsB.count ? partsB[i] : 0
            if numA < numB { return -1 }
            if numA > numB { return 1 }
        }
        return 0
    }
}

// MARK: - Setup Window View

struct SetupView: View {
    @ObservedObject var configManager = BrowserConfigManager.shared
    @ObservedObject var updateChecker = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Tab Switcher Setup")
                    .font(.title2.bold())
                Text("Select browsers to use with Tab Switcher")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Update banner
            if updateChecker.updateAvailable && !updateChecker.updateDismissed {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Available — Version \(updateChecker.latestVersion ?? "")")
                            .font(.subheadline.bold())
                        if let notes = updateChecker.releaseNotes {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let urlString = updateChecker.downloadUrl, let url = URL(string: urlString) {
                        Link("Download", destination: url)
                            .font(.subheadline.bold())
                    }
                    Button(action: { updateChecker.updateDismissed = true }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // Browser list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(configManager.installedBrowsers) { browser in
                        BrowserRowView(browser: browser)
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Footer
            VStack(spacing: 6) {
                HStack {
                    Text("\(configManager.browsers.filter { $0.isEnabled }.count) browser(s) enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Done") {
                        configManager.showingSetup = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!configManager.browsers.contains { $0.isEnabled })
                }
                Text("Version \(APP_VERSION)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding()
        }
        .frame(width: 450, height: 550)
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

struct BrowserRowView: View {
    let browser: BrowserInfo
    @ObservedObject var configManager = BrowserConfigManager.shared
    @State private var extensionId: String = ""
    @State private var isExpanded = false
    
    var currentBrowser: BrowserInfo? {
        configManager.browsers.first { $0.id == browser.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Browser icon
                if let icon = browser.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 30))
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.name)
                        .font(.headline)
                    
                    if let current = currentBrowser, current.isEnabled, let extId = current.extensionId {
                        Text("Enabled • \(extId.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Not configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if currentBrowser?.isEnabled == true {
                    Button("Disable") {
                        configManager.disableBrowser(id: browser.id)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Enable") {
                        isExpanded = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Settings for enabled browsers
            if let current = currentBrowser, current.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Toggle(isOn: Binding(
                        get: { current.combineAllWindows },
                        set: { configManager.setCombineWindows(id: browser.id, combine: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cycle through all windows")
                                .font(.subheadline)
                            Text("When off, only tabs from the active window are shown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // Expanded extension ID input
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    Text("Enter Extension ID")
                        .font(.subheadline.bold())
                    
                    Text("Find it in \(browser.name): Extensions → Developer Mode → Copy ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        PastableTextField(text: $extensionId, placeholder: "Paste extension ID here (32 chars)")
                            .frame(height: 24)
                        
                        Button("Cancel") {
                            extensionId = ""
                            isExpanded = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Save") {
                            if extensionId.count == 32 {
                                configManager.enableBrowser(id: browser.id, extensionId: extensionId)
                                isExpanded = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(extensionId.count != 32)
                    }
                    
                    if !extensionId.isEmpty && extensionId.count != 32 {
                        Text("Extension ID must be exactly 32 characters (\(extensionId.count)/32)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .onAppear {
            extensionId = currentBrowser?.extensionId ?? ""
        }
    }
}

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
                .onChange(of: state.selectedIndex) { newIndex in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(newIndex, anchor: .center)
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
    var setupWindow: NSWindow?
    var cancellable: AnyCancellable?
    var setupCancellable: AnyCancellable?
    var launchedDirectly = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup application menu (for Cmd+Q support)
        if launchedDirectly {
            setupMainMenu()
        }
        debugLog("App delegate launched, launchedDirectly=\(launchedDirectly)")
        
        // Create the floating window for tab switching UI
        window = TabSwitcherWindow()
        debugLog("Window created")
        
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
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 550),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            setupWindow?.title = "Tab Switcher Setup"
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
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    }
    
    func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Tab Switcher", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
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
        debugLog("Application will terminate - cleaning up event tap lock")
        cleanupEventTapLock()
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
            sendMessage(["action": "registered", "bundleId": ownerBrowserBundleId ?? bundleId])
        }
        
    case "ping":
        // Respond to ping to confirm connection is alive
        debugLog("Received ping, sending pong")
        sendMessage(["action": "pong"])
    
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

var ctrlIsPressed = false
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
            
            // Check for browser helper processes by name
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
    
    // Handle flags changed (modifier key state changes)
    if type == .flagsChanged {
        let ctrlNowPressed = flags.contains(.maskControl)
        
        // Detect Ctrl release
        if ctrlIsPressed && !ctrlNowPressed && switchInProgress {
            // Cancel any pending show UI timer
            showUITimer?.cancel()
            showUITimer = nil
            
            // Broadcast to ALL native hosts
            postCtrlReleaseNotification()
            switchInProgress = false
            tabPressCount = 0
        }
        
        ctrlIsPressed = ctrlNowPressed
        return Unmanaged.passRetained(event)
    }
    
    // Handle key down events
    if type == .keyDown {
        // Check for Tab key (keyCode 48)
        if keyCode == kVK_Tab && flags.contains(.maskControl) {
            if !switchInProgress {
                switchInProgress = true
                tabPressCount = 0
            }
            ctrlIsPressed = true
            tabPressCount += 1
            
            // Determine direction based on Shift key
            let direction = flags.contains(.maskShift) ? "cycle_prev" : "cycle_next"
            
            // Reload config from disk to pick up any changes made in the config UI
            BrowserConfigManager.shared.loadConfig()
            
            // Get the combineAllWindows setting - use false as default for safety
            let combineWindows = false
            
            debugLog("Broadcasting Ctrl+Tab: direction=\(direction), tabPressCount=\(tabPressCount)")
            
            if tabPressCount == 1 {
                // First Tab press: cycle but don't show UI yet
                postCtrlTabNotification(direction: direction, showUI: false, combineWindows: combineWindows)
                
                // Start timer to show UI after delay
                showUITimer?.cancel()
                let timer = DispatchWorkItem {
                    postRequestShowUINotification(combineWindows: combineWindows)
                }
                showUITimer = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + showUIDelay, execute: timer)
            } else {
                // Second+ Tab press: show UI immediately
                showUITimer?.cancel()
                showUITimer = nil
                postCtrlTabNotification(direction: direction, showUI: true, combineWindows: combineWindows)
            }
            
            // Suppress the event
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
        exit(0)
    }
    signal(SIGINT) { _ in
        cleanupEventTapLock()
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
    
    // Start update checker
    UpdateChecker.shared.startChecking()

    debugLog("Starting NSApplication run loop")
    app.run()
}

main()
