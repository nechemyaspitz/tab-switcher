import Foundation
import AppKit
import SwiftUI
import Carbon.HIToolbox

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
        
        // Check if any browser is enabled - if not, show setup
        if !browsers.contains(where: { $0.isEnabled }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showingSetup = true
            }
        }
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
        let nativeHostPath = "/Applications/Tab Switcher.app/Contents/MacOS/tab-switcher"
        
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

// MARK: - Setup Window View

struct SetupView: View {
    @ObservedObject var configManager = BrowserConfigManager.shared
    
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
        debugLog("App delegate launched")
        
        // Create the floating window
        window = TabSwitcherWindow()
        debugLog("Window created")
        
        // Observe setup window state - show/hide dock icon accordingly
        setupCancellable = BrowserConfigManager.shared.$showingSetup.sink { [weak self] showing in
            DispatchQueue.main.async {
                if showing {
                    // Show in dock when config UI is visible
                    NSApp.setActivationPolicy(.regular)
                    self?.showSetupWindow()
                } else {
                    self?.setupWindow?.close()
                    self?.setupWindow = nil
                    // Hide from dock when config UI is closed
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
        
        // If launched directly (not via native messaging), show setup
        if launchedDirectly {
            DispatchQueue.main.async {
                BrowserConfigManager.shared.showingSetup = true
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
        
        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            BrowserConfigManager.shared.showingSetup = true
        }
        return true
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
        if let bundleId = message["bundleId"] as? String {
            if ownerBrowserBundleId == nil {
                ownerBrowserBundleId = bundleId
                debugLog("Registered with browser (from extension): \(bundleId)")
            } else {
                debugLog("Already auto-detected browser: \(ownerBrowserBundleId!), ignoring extension registration: \(bundleId)")
            }
            sendMessage(["action": "registered", "bundleId": ownerBrowserBundleId ?? bundleId])
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
    
    // If we're registered with a specific browser, only respond to that one
    if let ownerBundle = ownerBrowserBundleId {
        let isOwner = bundleId == ownerBundle
        debugLog("Browser check: frontmost=\(bundleId), owner=\(ownerBundle), match=\(isOwner)")
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
    
    // If registered, only return if it's our owner browser
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

// Detect which browser launched this native host by checking parent process
func detectParentBrowser() -> String? {
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
                debugLog("Found browser at level \(level): \(bundleId)")
                return bundleId
            }
            
            // Check for browser helper processes by name
            if bundleId.contains("Chrome") || app.localizedName?.contains("Chrome") == true {
                debugLog("Found Chrome-related process, assuming com.google.Chrome")
                return "com.google.Chrome"
            }
            if bundleId.contains("Helium") || bundleId.contains("imput") {
                debugLog("Found Helium-related process")
                return "net.imput.helium"
            }
            if bundleId.contains("Brave") {
                return "com.brave.Browser"
            }
            if bundleId.contains("Edge") {
                return "com.microsoft.edgemac"
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
    guard isSupportedBrowserActive() else {
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
            
            sendAction("end_switch")
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
            
            // Get the combineAllWindows setting for the current browser
            let combineWindows = ownerBrowserBundleId.flatMap { bundleId in
                BrowserConfigManager.shared.browsers.first { $0.id == bundleId }?.combineAllWindows
            } ?? false
            
            debugLog("combineWindows=\(combineWindows) for browser \(ownerBrowserBundleId ?? "nil")")
            
            if tabPressCount == 1 {
                // First Tab press: cycle but don't show UI yet
                sendMessage(["action": direction, "show_ui": false, "current_window_only": !combineWindows])
                
                // Start timer to show UI after delay
                showUITimer?.cancel()
                let timer = DispatchWorkItem {
                    sendMessage(["action": "request_show_ui", "current_window_only": !combineWindows])
                }
                showUITimer = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + showUIDelay, execute: timer)
            } else {
                // Second+ Tab press: show UI immediately
                showUITimer?.cancel()
                showUITimer = nil
                sendMessage(["action": direction, "show_ui": true, "current_window_only": !combineWindows])
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

// Check if stdin is a TTY (launched directly) or pipe (launched via native messaging)
func isLaunchedDirectly() -> Bool {
    return isatty(STDIN_FILENO) != 0
}

// Check if another instance of the app is already running (for direct launch only)
func isAnotherInstanceRunning() -> Bool {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let runningApps = NSWorkspace.shared.runningApplications
    
    // Look for other instances of Tab Switcher that were launched directly (in dock)
    for app in runningApps {
        if app.bundleIdentifier == Bundle.main.bundleIdentifier,
           app.processIdentifier != currentPID,
           app.activationPolicy == .regular {
            return true
        }
    }
    return false
}

// Bring existing instance to front
func activateExistingInstance() {
    let runningApps = NSWorkspace.shared.runningApplications
    for app in runningApps {
        if app.bundleIdentifier == Bundle.main.bundleIdentifier,
           app.activationPolicy == .regular {
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }
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
    debugLog("Tab Switcher Native Host starting...")
    
    let directLaunch = isLaunchedDirectly()
    debugLog("Launched directly: \(directLaunch)")
    
    // For direct launches, check if another instance is already running
    if directLaunch {
        if isAnotherInstanceRunning() {
            debugLog("Another instance is already running, activating it instead")
            activateExistingInstance()
            exit(0)
        }
    }
    
    // Setup event tap first
    let eventTapSuccess = setupEventTap()
    if !eventTapSuccess {
        debugLog("Failed to setup event tap")
        // If launched directly, show alert about accessibility permission
        if directLaunch {
            // Need to initialize NSApp first for alerts
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            showAccessibilityAlert()
            
            // Continue with config UI only
            let delegate = AppDelegate()
            delegate.launchedDirectly = true
            app.delegate = delegate
            BrowserConfigManager.shared.showingSetup = true
            app.run()
            return
        }
        exit(1)
    }
    debugLog("Event tap setup complete")
    
    // Only start message reader if launched via native messaging
    if !directLaunch {
        // Detect which browser launched us BEFORE anything else
        if let detectedBrowser = detectParentBrowser() {
            ownerBrowserBundleId = detectedBrowser
            debugLog("Auto-detected owner browser: \(detectedBrowser)")
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
    
    debugLog("Starting NSApplication run loop")
    app.run()
}

main()
