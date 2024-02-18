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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SuggestionTextField(modelProvider: modelProvider)
                .autocorrectionDisabled()
            
            Divider()
            
            if modelProvider.searchText.isEmpty {
                MenuBarStyleButton(keyboardShortcut: Text(Image(systemName: "command")) + Text(" R")) {
                    // refresh
                } label: {
                    Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                }
                .keyboardShortcut(.init("r"), modifiers: .command)
                
                MenuBarStyleButton(keyboardShortcut: Text(Image(systemName: "command")) + Text(" ,")) {
                    openWindow(id: "configuration")
                } label: {
                    Label("Settings...", systemImage: "gearshape")
                }
                .keyboardShortcut(.init(","), modifiers: .command)
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
