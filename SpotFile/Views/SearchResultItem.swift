//
//  SearchResultItem.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/18.
//

import SwiftUI
import Stratum
import ViewCollection

struct SearchResultItem: View {
    
    let index: Int
    
    let item: any QueryItemProtocol
    
    let match: QueryItem.Match
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(\.modelContext) private var modelContext
    
    
    @State private var hovering = false
    
    private var isSelected: Bool {
        index == modelProvider.selectionIndex
    }
    
    private var relativePath: (folder: String, name: Substring)? {
        if isSelected,
           !item.openableFileRelativePath.isEmpty,
           let name = item.openableFileRelativePath.components(separatedBy: "/").last,
           let _item = modelProvider.previous.matches.first,
           let relative = item.item.relativePath(to: _item.item) {
            let folder = relative.dropLast(name.count + 1)
            if !folder.isEmpty {
                return (name, folder)
            }
        }
        
        return nil
    }
    
    
    @ViewBuilder
    var help: some View {
        if let (name, folder) = relativePath {
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .fontWeight(.medium)
                Text(folder)
                    .lineSpacing(0)
                    .font(.callout)
                    .opacity(0.9)
                    .fontWeight(.light)
            }
        } else {
            Text(item.openableFileRelativePath)
        }
    }
    
    
    var body: some View {
        HStack {
            IconView(item: item, scale: .small, isSelected: isSelected)
            
            if isSelected && item is QueryItemChild {
                help
            } else {
                if match.isPrimary {
                    match.text
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.query.content)
                            .fontWeight(.medium)
                        (Text("aka: ").foregroundStyle(.secondary) + match.text)
                            .lineSpacing(-10)
                            .font(.callout)
                            .opacity(0.9)
                            .fontWeight(.light)
                    }
                }
            }
            
            Spacer()
            
            if isSelected {
                Button {
                    item.reveal(query: modelProvider.searchText, context: modelContext)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
                .opacity(hovering ? 0.8 : 0)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.leading, 7)
        .padding(.vertical, 2.5)
        .frame(maxWidth: .infinity)
        .frame(height: (relativePath != nil || !match.isPrimary) ? 35 : 25)
        .background(isSelected ? Color.accentColor : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            self.hovering = hovering
        }
        .onTapGesture {
            if modelProvider.selectionIndex != index {
                modelProvider.selectionIndex = index
            } else {
                item.open(query: modelProvider.searchText, context: modelContext)
            }
        }
        .contextMenu {
            Button("Open") {
                item.open(query: modelProvider.searchText, context: modelContext)
            }
            Button("Show in Enclosing Folder") {
                item.reveal(query: modelProvider.searchText, context: modelContext)
            }
            
            Divider()
            
            Button("Copy") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([item.item.url as NSPasteboardWriting])
            }
            
            Button("Copy as pathname") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(item.item.path, forType: .string)
            }
        }
    }
}

#Preview {
    SearchResultItem(index: 0, item: QueryItem.preview, match: .init(text: Text("here"), isPrimary: true))
        .environment(ModelProvider.preview)
        .frame(width: 200)
}

#Preview {
    SearchResultItem(index: 0, item: QueryItemChild.preview, match: .init(text: Text("here"), isPrimary: true))
        .environment(ModelProvider.preview)
        .frame(width: 200)
}
