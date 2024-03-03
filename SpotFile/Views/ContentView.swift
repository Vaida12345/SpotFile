//
//  ContentView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(\.openWindow) private var openWindow 
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    @EnvironmentObject private var appDelegate: SpotFileApp.ApplicationDelegate
    
    
    @State private var isSyncing = false
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SuggestionTextField(modelProvider: modelProvider)
                .autocorrectionDisabled()
            
            if modelProvider.searchText.isEmpty {
                MenuBarStyleButton(keyboardShortcut: Text(Image(systemName: "command")) + Text(" ,")) {
                    NSApp.setActivationPolicy(.regular)
                    openWindow(id: "configuration")
                    if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
                        settingsWindow.makeKeyAndOrderFront(nil)
                        settingsWindow.becomeFirstResponder()
                        settingsWindow.delegate = appDelegate
                        NSApp.activate(ignoringOtherApps: true)
                    }
                } label: {
                    Text("Settings...")
                }
                .keyboardShortcut(.init(","), modifiers: .command)
                
                Divider()
                    .padding(.horizontal, 7)
                
                MenuBarStyleButton(keyboardShortcut: Text(Image(systemName: "command")) + Text(" Q")) {
                    try? ModelProvider.instance.save()
                    exit(0)
                } label: {
                    Text("Quit SpotFile")
                }
                .keyboardShortcut(.init("q"), modifiers: .command)
            } else {
                SearchResultView()
            }
        }
        .padding(.all, 5)
    }
}

#Preview {
    ContentView()
        .frame(width: 200)
}


extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}
