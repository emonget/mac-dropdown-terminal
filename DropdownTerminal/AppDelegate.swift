import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuBarController: MenuBarController!
    var settingsManager: SettingsManager!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        settingsManager = SettingsManager()
        menuBarController = MenuBarController(settingsManager: settingsManager)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}