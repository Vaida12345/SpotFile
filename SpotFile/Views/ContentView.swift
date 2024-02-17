//
//  ContentView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI

struct ContentView: View {
    
    @State private var searchText = ""
    
    @Environment(\.openWindow) private var openWindow 
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.thinMaterial)
                }
                .autocorrectionDisabled()
            
            Divider()
            
            if searchText.isEmpty {
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
                ScrollView {
                    VStack {
                        let items = modelProvider.items.map { ($0, $0.match(query: searchText)) }.filter { $0.1 != nil }
                        ForEach(items, id: \.0.id) { (item, match) in
                            
                            Text(match!)
                        }
                    }
                }
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
