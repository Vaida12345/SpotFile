//
//  SpotFileApp.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI
import Stratum
import SwiftData


@main
struct SpotFileApp: App {
    
    @State private var modelProvider = ModelProvider.instance
    
    @Environment(\.dismissWindow) private var dismissWindow
    
    let modelContainer = try! ModelContainer(for: QueryChildRecord.self, configurations: ModelConfiguration(url: URL(filePath: NSHomeDirectory() + "/Library/Containers/Vaida.app.SpotFile/Data/Library/Application Support/default.store")))
    
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .background(.ultraThinMaterial)
                .environment(modelProvider)
                .environmentObject(applicationDelegate)
                .modelContainer(modelContainer)
        } label: {
            Image("SpotFile")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
        
        Window("Settings", id: "configuration") {
            SettingsView()
                .environment(modelProvider)
                .modelContainer(modelContainer)
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
            
            CommandGroup(after: .saveItem) {
                Button("Close Window") {
                    dismissWindow(id: "configuration")
                }
                .keyboardShortcut(.init("w"), modifiers: .command)
            }
        }
    }
    
    
#if canImport (AppKit)
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate

    final class ApplicationDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
        
        func applicationWillTerminate(_ notification: Notification) {
            try? ModelProvider.instance.save()
        }
        
        func windowWillClose(_ notification: Notification) {
            NSApp.setActivationPolicy(.accessory)
            Task.detached {
                try? ModelProvider.instance.save()
            }
        }
    }
#endif
}
