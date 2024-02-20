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
    
    @State private var searchText = ""
    
    @Environment(\.undoManager) private var undoManager
    
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(modelProvider.items.filter { !searchText.isEmpty => $0.match(query: searchText) != nil }) { item in
                    HStack {
                        item.smallIconView
                            .frame(width: 20, height: 20)
                        Text(item.query)
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Button {
                    let newItem = QueryItem.new()
                    defer {
                        withAnimation {
                            selectedItem = newItem.id
                        }
                    }
                    modelProvider.append(newItem, to: \.items, undoManager: undoManager)
                } label: {
                    Label("New", systemImage: "plus")
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding()
                .keyboardShortcut(.init("n"))
            }
        } detail: {
            if let selection = modelProvider.items.first(where: { $0.id == selectedItem }) {
                SettingsSelectionView(selection: selection)
            } else {
                Text("Select an item on the left\nOr add a new item.")
                    .bold()
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
            }
        }
        .searchable(text: $searchText)
    }
}

#Preview {
    SettingsView()
        .environment(ModelProvider.preview)
}
