import Foundation

class SettingsManager {
    
    private let userDefaults = UserDefaults.standard
    private let selectedAppKey = "DropdownTerminal_SelectedApp"
    private let defaultApp = "Terminal"
    
    init() {
        registerDefaults()
    }
    
    private func registerDefaults() {
        userDefaults.register(defaults: [
            selectedAppKey: defaultApp
        ])
    }
    
    func getSelectedApp() -> String {
        return userDefaults.string(forKey: selectedAppKey) ?? defaultApp
    }
    
    func setSelectedApp(_ appName: String) {
        userDefaults.set(appName, forKey: selectedAppKey)
        userDefaults.synchronize()
    }
}