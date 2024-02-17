//
//  SettingsView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/12.
//

import SwiftUI
import Stratum

struct SettingsView: View {
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    @State private var selectedItem: UUID?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("File") {
                    ForEach(modelProvider.items) { item in
                        Text(item.query)
                    }
                    
                    Button("new...") {
                        let newItem = QueryItem.new()
                        defer {
                            withAnimation {
                                selectedItem = newItem.id
                            }
                        }
                        withAnimation {
                            modelProvider.items.append(newItem)
                        }
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                
                Section("Folder") {
                    
                }
            }
        } detail: {
            if let selection = modelProvider.items.first(where: { $0.id == selectedItem }) {
                SettingsSelectionView(selection: selection)
            }
        }

    }
}

#Preview {
    SettingsView()
        .environment(ModelProvider.preview)
}
