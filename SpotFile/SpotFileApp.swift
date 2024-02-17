//
//  SpotFileApp.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI

@main
struct SpotFileApp: App {
    
    @State private var modelProvider = ModelProvider.instance
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .background(.ultraThinMaterial)
                .environment(modelProvider)
        } label: {
            Image(systemName: "text.magnifyingglass")
                .imageScale(.large)
        }
        .menuBarExtraStyle(.window)
        
        Window("Settings", id: "configuration") {
            SettingsView()
                .environment(modelProvider)
        }
    }
    
    
#if canImport (AppKit)
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate

    final class ApplicationDelegate: NSObject, NSApplicationDelegate {
        
        func applicationWillTerminate(_ notification: Notification) {
            print("will persist")
            try! ModelProvider.instance.save()
        }
    }
#endif
}
