//
//  SpotFileApp.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI
import Stratum

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
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    do {
                        try ModelProvider.instance.save()
                    } catch {
                        AlertManager(error).present()
                    }
                }
                .keyboardShortcut(.init("s"), modifiers: .command)
            }
        }
    }
    
    
#if canImport (AppKit)
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate

    final class ApplicationDelegate: NSObject, NSApplicationDelegate {
        
        func applicationWillTerminate(_ notification: Notification) {
            try! ModelProvider.instance.save()
        }
    }
#endif
}
