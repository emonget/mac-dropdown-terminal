import Cocoa
import os.log

// Early startup check
private func earlyStartupCheck() {
    print("🔧 DropdownTerminal main() called - app is starting")
}

// Get version information from bundle
private func getVersionInfo() -> String {
    let bundle = Bundle.main
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    let commit = bundle.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
    
    let shortCommit = String(commit.prefix(7))
    return "v\(version) (\(build)) - \(shortCommit)"
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuBarController: MenuBarController!
    var settingsManager: SettingsManager!
    
    private let logger = Logger(subsystem: "com.dropdownterminal.DropdownTerminal", category: "AppDelegate")
    
    override init() {
        print("🔧 AppDelegate init() called - very first step")
        super.init()
        print("🔧 AppDelegate init() completed")
        
        // Show version info
        let version = getVersionInfo()
        print("📦 DropdownTerminal \(version)")
        logger.info("🔧 AppDelegate initialized")
        logger.info("📦 Version: \(version)")
        earlyStartupCheck()
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        print("🔧 applicationWillFinishLaunching called")
        logger.info("🔧 applicationWillFinishLaunching")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 applicationDidFinishLaunching called")
        logger.info("🚀 DropdownTerminal starting up...")
        
        do {
            print("🔧 Creating settings manager...")
            settingsManager = SettingsManager()
            logger.info("✅ Settings manager initialized")
            print("✅ Settings manager OK")
            
            print("🔧 Creating menu bar controller...")
            menuBarController = MenuBarController(settingsManager: settingsManager)
            logger.info("✅ Menu bar controller initialized")
            print("✅ Menu bar controller OK")
            
            logger.info("🎯 DropdownTerminal ready! Check menu bar for icon.")
            
            // Print to console as well for direct terminal launches
            print("🚀 DropdownTerminal is running - look for icon in menu bar")
            print("📱 Selected app: \(settingsManager.getSelectedApp())")
        } catch {
            print("❌ FATAL ERROR during startup: \(error)")
            logger.error("❌ FATAL ERROR: \(error.localizedDescription)")
            NSApplication.shared.terminate(nil)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}