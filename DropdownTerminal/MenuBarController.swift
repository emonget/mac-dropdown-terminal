import Cocoa
import ApplicationServices
import os.log

// Private API declarations for space management
typealias CGSSpaceID = UInt64
typealias CGSConnectionID = UInt32

@_silgen_name("_CGSDefaultConnection") 
func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ connection: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSMoveWindowsToManagedSpace")
func CGSMoveWindowsToManagedSpace(_ connection: CGSConnectionID, _ windows: CFArray, _ space: CGSSpaceID) -> CGError

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

class MenuBarController: NSObject {
    
    private var statusItem: NSStatusItem!
    private var settingsManager: SettingsManager!
    private var isTerminalVisible = false
    private var contextMenu: NSMenu!
    
    private let activeIcon = "terminal.badge.plus"
    private let inactiveIcon = "terminal"
    
    private let logger = Logger(subsystem: "com.dropdownterminal.DropdownTerminal", category: "MenuBarController")
    
    init(settingsManager: SettingsManager) {
        super.init()
        self.settingsManager = settingsManager
        logger.info("🎛️ Initializing menu bar controller...")
        setupMenuBar()
        updateTerminalVisibilityState()
        updateMenuBarIcon()
        logger.info("✅ Menu bar controller ready")
    }
    
    private func setupMenuBar() {
        logger.info("📋 Setting up menu bar item...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem.button else {
            logger.error("❌ Could not create status bar button")
            fatalError("Could not create status bar button")
        }
        
        logger.info("🔘 Status bar button created successfully")
        
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        setupContextMenu()
        logger.info("📝 Menu bar setup complete")
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        let appSelectionItem = NSMenuItem(title: "Select App", action: #selector(showAppSelection), keyEquivalent: "")
        appSelectionItem.target = self
        menu.addItem(appSelectionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Store menu separately - don't assign to statusItem.menu
        // We'll show it manually on right-click only
        self.contextMenu = menu
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            logger.info("🖱️ Right-click detected - showing context menu")
            print("🖱️ Right-click: Opening settings menu")
            contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
        } else {
            logger.info("🖱️ Left-click detected - toggling terminal")
            print("🖱️ Left-click: Toggling terminal")
            toggleTerminal()
        }
    }
    
    @objc private func toggleTerminal() {
        let appName = settingsManager.getSelectedApp()
        logger.info("🔄 Toggling terminal app: \(appName)")
        
        if let app = findRunningApp(appName) {
            logger.info("📱 Found running app: \(app.localizedName ?? "Unknown")")
            let wasVisible = isAppVisible(app)
            logger.info("🔍 Current visibility state: \(wasVisible)")
            
            if wasVisible {
                logger.info("👁️ App is visible, hiding it")
                hideApp(app)
                isTerminalVisible = false
            } else {
                logger.info("👻 App is hidden, showing it")
                showApp(app)
                isTerminalVisible = true
            }
        } else {
            logger.info("🚀 App not running, launching it")
            launchApp(appName)
            isTerminalVisible = true
        }
        
        logger.info("🎯 Final state: isTerminalVisible = \(isTerminalVisible)")
        updateMenuBarIcon()
    }
    
    private func findRunningApp(_ appName: String) -> NSRunningApplication? {
        let normalizedAppName = appName.lowercased()
        
        // First try exact match by localized name
        if let app = NSWorkspace.shared.runningApplications.first(where: { 
            $0.localizedName?.lowercased() == normalizedAppName 
        }) {
            return app
        }
        
        // Then try bundle identifier contains
        if let app = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier?.lowercased().contains(normalizedAppName) == true 
        }) {
            return app
        }
        
        // Finally try partial name match
        return NSWorkspace.shared.runningApplications.first(where: { 
            $0.localizedName?.lowercased().contains(normalizedAppName) == true 
        })
    }
    
    private func isAppVisible(_ app: NSRunningApplication) -> Bool {
        // Check if app is hidden at application level
        if app.isHidden {
            logger.info("🙈 App is hidden at application level")
            return false
        }
        
        // Check if app is active (frontmost)
        if app == NSWorkspace.shared.frontmostApplication {
            logger.info("🎯 App is frontmost application")
            return true
        }
        
        // Check if app has visible windows using Accessibility API
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        if result == .success, let windows = windowList as? [AXUIElement], !windows.isEmpty {
            logger.info("🪟 Found \(windows.count) windows for app")
            // Check if any window is visible (not minimized)
            for (index, window) in windows.enumerated() {
                var minimized: CFTypeRef?
                let minResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
                
                if minResult == .success, let isMinimized = minimized as? Bool {
                    logger.info("📱 Window \(index): minimized = \(isMinimized)")
                    if !isMinimized {
                        // Also check if window is actually visible on screen
                        var position: CFTypeRef?
                        let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
                        if posResult == .success {
                            return true
                        }
                    }
                } else {
                    logger.info("⚠️ Could not check minimized state for window \(index)")
                }
            }
        } else {
            logger.info("❌ Could not get windows for app, result: \(result.rawValue)")
        }
        
        logger.info("👻 No visible windows found")
        return false
    }
    
    private func showApp(_ app: NSRunningApplication) {
        logger.info("📺 Showing app: \(app.localizedName ?? "Unknown")")
        
        // First, get all windows for this app and move them to current space
        moveAppWindowsToCurrentSpace(app)
        
        // Don't activate the app - just unhide it and bring windows to front
        if app.isHidden {
            app.unhide()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = self.getAppMainWindow(app) {
                self.bringToFront(window)
            }
        }
    }
    
    private func hideApp(_ app: NSRunningApplication) {
        app.hide()
    }
    
    private func launchApp(_ appName: String) {
        logger.info("🚀 Launching app: \(appName)")
        let workspace = NSWorkspace.shared
        
        // Try to launch the app
        let success: Bool
        if appName.lowercased().contains("terminal") {
            success = workspace.launchApplication("Terminal")
        } else {
            success = workspace.launchApplication(appName)
        }
        
        if !success {
            logger.error("❌ Failed to launch app: \(appName)")
            return
        }
        
        // Wait for app to start and then move it to current space
        waitForAppToLaunch(appName, attempts: 10)
    }
    
    private func waitForAppToLaunch(_ appName: String, attempts: Int) {
        if attempts <= 0 {
            logger.error("❌ Timeout waiting for app to launch: \(appName)")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let app = self.findRunningApp(appName) {
                self.logger.info("✅ App launched successfully: \(app.localizedName ?? "Unknown")")
                // Wait a bit more for windows to be created
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showApp(app)
                }
            } else {
                self.logger.info("⏳ Still waiting for app to launch... (\(attempts) attempts left)")
                self.waitForAppToLaunch(appName, attempts: attempts - 1)
            }
        }
    }
    
    private func moveAppWindowsToCurrentSpace(_ app: NSRunningApplication) {
        logger.info("🔄 Moving app windows to current space for: \(app.localizedName ?? "Unknown")")
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        if result == .success, let windows = windowList as? [AXUIElement] {
            logger.info("📱 Found \(windows.count) windows to move")
            for (index, window) in windows.enumerated() {
                logger.info("🔄 Moving window \(index + 1)/\(windows.count)")
                moveWindowToCurrentSpace(window)
            }
        } else {
            logger.warning("⚠️ Could not get window list for app, result: \(result.rawValue)")
        }
    }
    
    private func moveWindowToCurrentSpace(_ window: AXUIElement) {
        // Get current space ID
        guard let currentSpaceID = getCurrentSpaceInfo() else { 
            logger.error("❌ Could not get current space info")
            return 
        }
        
        // Move window to current space using private APIs
        let windowID = getWindowID(window)
        if windowID > 0 {
            logger.info("🏠 Moving window \(windowID) to space \(currentSpaceID)")
            let result = moveWindowToSpace(windowID: windowID, spaceID: currentSpaceID)
            if result == .success {
                logger.info("✅ Successfully moved window to current space")
            } else {
                logger.error("❌ Failed to move window to current space, error: \(result.rawValue)")
            }
        } else {
            logger.warning("⚠️ Could not get window ID for window")
        }
    }
    
    private func getCurrentSpaceInfo() -> CGSSpaceID? {
        let connection = _CGSDefaultConnection()
        return CGSGetActiveSpace(connection)
    }
    
    private func getWindowID(_ window: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0
        let _ = _AXUIElementGetWindow(window, &windowID)
        return windowID
    }
    
    private func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) -> CGError {
        let connection = _CGSDefaultConnection()
        return CGSMoveWindowsToManagedSpace(connection, [windowID] as CFArray, spaceID)
    }
    
    private func getAppMainWindow(_ app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var mainWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindow)
        
        if result == .success, let window = mainWindow {
            return (window as! AXUIElement)
        }
        
        // Fallback: get first window if no main window
        var windowList: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        if windowsResult == .success, let windows = windowList as? [AXUIElement], !windows.isEmpty {
            return windows[0]
        }
        
        return nil
    }
    
    private func getFrontmostWindow() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var frontmostApp: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &frontmostApp)
        
        if result == .success, let app = frontmostApp {
            var frontmostWindow: CFTypeRef?
            let windowResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &frontmostWindow)
            
            if windowResult == .success {
                return (frontmostWindow as! AXUIElement)
            }
        }
        
        return nil
    }
    
    private func bringToFront(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
    
    private func updateTerminalVisibilityState() {
        let appName = settingsManager.getSelectedApp()
        if let app = findRunningApp(appName) {
            self.isTerminalVisible = isAppVisible(app)
            logger.info("🔍 Initial terminal visibility state: \(self.isTerminalVisible)")
        } else {
            self.isTerminalVisible = false
            logger.info("🔍 Terminal not running, setting visibility to false")
        }
    }
    
    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { 
            logger.error("❌ Status bar button not available for icon update")
            return 
        }
        
        let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        
        // Fallback to text if SF Symbols not available
        if image == nil {
            let title = isTerminalVisible ? "●" : "○"
            button.title = title
            button.image = nil
            logger.info("🔤 Using text fallback icon: \(title)")
            print("📱 Menu bar icon: \(title) (text fallback)")
        } else {
            image?.size = NSSize(width: 18, height: 18)
            
            if isTerminalVisible {
                // Active state: Blue terminal icon with slight glow
                let activeImage = image?.copy() as? NSImage
                activeImage?.lockFocus()
                
                // Create blue version
                NSColor.systemBlue.setFill()
                let rect = NSRect(origin: .zero, size: image?.size ?? .zero)
                rect.fill(using: .sourceAtop)
                
                activeImage?.unlockFocus()
                activeImage?.isTemplate = false
                
                button.image = activeImage
                logger.info("🔵 Active terminal icon (blue)")
            } else {
                // Inactive state: Standard template icon (follows system theme)
                image?.isTemplate = true
                button.image = image
                logger.info("⚪ Inactive terminal icon (template)")
            }
            
            button.title = ""
            print("📱 Menu bar icon: terminal (\(isTerminalVisible ? "active-blue" : "inactive-template"))")
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DropdownTerminal"
        
        let versionInfo = getVersionInfo()
        alert.informativeText = """
        A macOS menu bar app for Guake-style terminal toggling.
        
        Build Timestamp: \(versionInfo.buildDate)
        Commit: \(versionInfo.commit)
        """
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func getVersionInfo() -> (version: String, build: String, buildDate: String, commit: String) {
        let bundle = Bundle.main
        
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        var commit = bundle.object(forInfoDictionaryKey: "GitCommit") as? String ?? "Unknown"
        var buildDate = bundle.object(forInfoDictionaryKey: "BuildTimestamp") as? String ?? "Unknown"
        
        // If no timestamp, try other sources
        if buildDate == "Unknown" {
            buildDate = bundle.object(forInfoDictionaryKey: "BuildDate") as? String ?? "Unknown"
            
            // Try to read build-info.txt from Resources folder (created by CI/CD)
            if buildDate == "Unknown", let buildInfoPath = bundle.path(forResource: "build-info", ofType: "txt"),
               let buildInfoContent = try? String(contentsOfFile: buildInfoPath) {
                
                let lines = buildInfoContent.components(separatedBy: .newlines)
                for line in lines {
                    if line.hasPrefix("Commit: ") && commit == "Unknown" {
                        commit = String(line.dropFirst("Commit: ".count))
                    } else if line.hasPrefix("Built: ") {
                        buildDate = String(line.dropFirst("Built: ".count))
                    }
                }
            }
            
            // Final fallback: Get timestamp from bundle creation date
            if buildDate == "Unknown" {
                if let bundlePath = bundle.bundlePath as NSString?,
                   let attributes = try? FileManager.default.attributesOfItem(atPath: bundlePath as String),
                   let creationDate = attributes[.creationDate] as? Date {
                    let timestamp = Int64(creationDate.timeIntervalSince1970 * 1000)
                    buildDate = String(timestamp)
                }
            }
        }
        
        // Truncate commit to first 8 characters for display
        if commit != "Unknown" && commit.count > 8 {
            commit = String(commit.prefix(8))
        }
        
        return (version: version, build: build, buildDate: buildDate, commit: commit)
    }
    
    private func formatBuildDate(_ dateString: String) -> String {
        // Handle ISO date format from CI (e.g., "2024-01-01 12:00:00 +0000")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        // If ISO format fails, try other common formats
        let commonFormats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "EEE MMM d HH:mm:ss yyyy",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        ]
        
        for format in commonFormats {
            let testFormatter = DateFormatter()
            testFormatter.dateFormat = format
            if let date = testFormatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                return displayFormatter.string(from: date)
            }
        }
        
        // If all else fails, return the original string
        return dateString
    }
    
    @objc private func showAppSelection() {
        let alert = NSAlert()
        alert.messageText = "Select Terminal Application"
        alert.informativeText = "Choose which application to toggle:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = settingsManager.getSelectedApp()
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newApp = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newApp.isEmpty {
                settingsManager.setSelectedApp(newApp)
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}