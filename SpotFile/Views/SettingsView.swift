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
    
    
    var groups: [String : [QueryItem]] {
        let items = modelProvider.items.filter { !searchText.isEmpty => $0.match(query: searchText) != nil }
        var dict = [String : [QueryItem]](grouping: items, by: { $0.query.components.first?.value ?? "" })
        for (key, value) in dict {
            if value.count == 1 {
                dict.removeValue(forKey: key)
                dict["", default: []].append(contentsOf: value)
            }
        }
        return dict
    }
    
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedItem) {
                    ForEach(Array(groups).sorted(on: \.key, by: <), id: \.key) { item in
                        lists(item.key, for: item.value)
                    }
                }
                .scrollIndicators(.never)
                
                Divider()
                
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
                .padding(.all, 8)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .keyboardShortcut(.init("n"))
            }
        } detail: {
            if let selection = modelProvider.items.first(where: { $0.id == selectedItem }) {
                SettingsSelectionView(selection: selection)
                    .id(selectedItem)
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
    
    
    func lists(_ title: String, for items: [QueryItem]) -> some View {
        let lists = ForEach(items.sorted(on: \.query.content, by: <)) { item in
            var value: String {
                if title.isEmpty {
                    return item.query.content
                } else {
                    let _value = item.query.content.dropFirst(title.count)
                    return String(_value.dropFirst(while: { $0.isWhitespace }))
                }
            }
            
            return HStack {
                item.smallIconView(isSelected: selectedItem == item.id)
                    .frame(width: 20, height: 20)
                Text(value)
            }
        }
        
        return Group {
            if title.isEmpty {
                Section {
                    lists
                }
            } else {
                Section(title) {
                    lists
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(ModelProvider.preview)
}
