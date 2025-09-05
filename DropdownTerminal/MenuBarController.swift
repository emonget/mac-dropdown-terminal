import Cocoa
import ApplicationServices

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
    
    private let activeIcon = "terminal.badge.plus"
    private let inactiveIcon = "terminal"
    
    init(settingsManager: SettingsManager) {
        super.init()
        self.settingsManager = settingsManager
        setupMenuBar()
        updateMenuBarIcon()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem.button else {
            fatalError("Could not create status bar button")
        }
        
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        setupContextMenu()
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        let appSelectionItem = NSMenuItem(title: "Select App", action: #selector(showAppSelection), keyEquivalent: "")
        appSelectionItem.target = self
        menu.addItem(appSelectionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
        } else {
            toggleTerminal()
        }
    }
    
    @objc private func toggleTerminal() {
        let appName = settingsManager.getSelectedApp()
        
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName || $0.bundleIdentifier?.contains(appName.lowercased()) == true }) {
            if isTerminalVisible {
                hideApp(app)
            } else {
                showApp(app)
            }
        } else {
            launchApp(appName)
        }
        
        isTerminalVisible.toggle()
        updateMenuBarIcon()
    }
    
    private func showApp(_ app: NSRunningApplication) {
        // First, get all windows for this app and move them to current space
        moveAppWindowsToCurrentSpace(app)
        
        // Then activate the app without switching spaces
        app.activate(options: [.activateIgnoringOtherApps])
        
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
        let workspace = NSWorkspace.shared
        
        if appName.lowercased().contains("terminal") {
            workspace.launchApplication("Terminal")
        } else {
            workspace.launchApplication(appName)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isTerminalVisible = true
            self.updateMenuBarIcon()
        }
    }
    
    private func moveAppWindowsToCurrentSpace(_ app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        if result == .success, let windows = windowList as? [AXUIElement] {
            for window in windows {
                moveWindowToCurrentSpace(window)
            }
        }
    }
    
    private func moveWindowToCurrentSpace(_ window: AXUIElement) {
        // Get current space ID
        guard let currentSpaceInfo = getCurrentSpaceInfo() else { return }
        
        // Move window to current space using private APIs
        let windowID = getWindowID(window)
        if windowID > 0 {
            moveWindowToSpace(windowID: windowID, spaceID: currentSpaceInfo)
        }
    }
    
    private func getCurrentSpaceInfo() -> CGSSpaceID? {
        let connection = _CGSDefaultConnection()
        return CGSGetActiveSpace(connection)
    }
    
    private func getWindowID(_ window: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0
        _AXUIElementGetWindow(window, &windowID)
        return windowID
    }
    
    private func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) {
        let connection = _CGSDefaultConnection()
        CGSMoveWindowsToManagedSpace(connection, [windowID] as CFArray, spaceID)
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
    
    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        
        let iconName = isTerminalVisible ? activeIcon : inactiveIcon
        var image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        
        // Fallback to text if SF Symbols not available
        if image == nil {
            let title = isTerminalVisible ? "●" : "○"
            button.title = title
            button.image = nil
        } else {
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
            button.title = ""
        }
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