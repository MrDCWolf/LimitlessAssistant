//
//  LimitlessAssistantApp.swift
//  LimitlessAssistant
//
//  Created by Wolf on 5/7/25.
//

import SwiftUI

@main
struct LimitlessAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        // Add the Settings scene
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
