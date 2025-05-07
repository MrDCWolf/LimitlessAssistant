import SwiftUI

@main
struct LimitlessAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView() // Placeholder main view
        }
        
        Settings { // Add the Settings scene
            SettingsView()
        }
    }
} 