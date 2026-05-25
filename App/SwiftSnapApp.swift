import SwiftUI

@main
struct SwiftSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: AppSettings.shared)
        }
    }
}
