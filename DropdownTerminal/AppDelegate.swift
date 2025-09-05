import Cocoa
import os.log

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuBarController: MenuBarController!
    var settingsManager: SettingsManager!
    
    private let logger = Logger(subsystem: "com.dropdownterminal.DropdownTerminal", category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("🚀 DropdownTerminal starting up...")
        
        settingsManager = SettingsManager()
        logger.info("✅ Settings manager initialized")
        
        menuBarController = MenuBarController(settingsManager: settingsManager)
        logger.info("✅ Menu bar controller initialized")
        
        logger.info("🎯 DropdownTerminal ready! Check menu bar for icon.")
        
        // Print to console as well for direct terminal launches
        print("🚀 DropdownTerminal is running - look for icon in menu bar")
        print("📱 Selected app: \(settingsManager.getSelectedApp())")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}