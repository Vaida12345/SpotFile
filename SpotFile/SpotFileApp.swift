//
//  SpotFileApp.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import Essentials
import SwiftUI
import SwiftData
import ViewCollection


@main
struct SpotFileApp: App {
    
    @State private var modelProvider = ModelProvider.instance
    
    @Environment(\.dismissWindow) private var dismissWindow
    
    @ApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    let modelContainer = try! ModelContainer(
        for: QueryChildRecord.self,
        configurations: ModelConfiguration(url: URL(filePath: NSHomeDirectory() + "/Library/Containers/Vaida.app.SpotFile/Data/Library/Application Support/default.store"))
    )
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .background(.ultraThinMaterial)
                .environment(modelProvider)
                .environmentObject(applicationDelegate)
                .modelContainer(modelContainer)
                .transaction { $0.animation = nil }
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
                .onAppear {
                    guard let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) else { return }
                    print("order front: \(window)")
                    window.makeKeyAndOrderFront(nil)
                }
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button {
                    withErrorPresented("Failed to save") {
                        try ModelProvider.instance.save()
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut(.init("s"), modifiers: .command)
            }
            
            CommandGroup(after: .saveItem) {
                Button {
                    dismissWindow(id: "configuration")
                } label: {
                    Label("Close Window", systemImage: "xmark")
                }
                .keyboardShortcut(.init("w"), modifiers: .command)
            }
            
            InspectorCommands()
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
            try? ModelProvider.instance.save()
        }
    }
#endif
}
