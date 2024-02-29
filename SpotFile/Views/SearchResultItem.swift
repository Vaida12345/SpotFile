//
//  SearchResultItem.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/18.
//

import SwiftUI
import Stratum

struct SearchResultItem: View {
    
    let index: Int
    
    let item: any QueryItemProtocol
    
    let match: Text
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    
    @State private var hovering = false
    
    var help: String {
        if !item.openableFileRelativePath.isEmpty,
            let name = item.openableFileRelativePath.components(separatedBy: "/").last {
            return name
        } else {
            return item.openableFileRelativePath
        }
    }
    
    
    var body: some View {
        HStack {
            Group {
                if let item = item as? QueryItem {
                    item.smallIconView(isSelected: index == modelProvider.selectionIndex)
                } else if index == 0, let item = item as? QueryItemChild {
                    item.smallIconView(isSelected: index == modelProvider.selectionIndex)
                } else {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 20, height: 20)
            
            match
            
            Spacer()
            
            if index == modelProvider.selectionIndex {
                Button {
                    withErrorPresented {
                        item.reveal(query: modelProvider.searchText)
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
                .opacity(hovering ? 0.8 : 0)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .help(help)
        .foregroundStyle(index == modelProvider.selectionIndex ? .white : .primary)
        .padding(.vertical, 5)
        .padding(.leading, 7)
        .frame(maxWidth: .infinity)
        .frame(height: 25)
        .background(index == modelProvider.selectionIndex ? Color.accentColor : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            self.hovering = hovering
        }
        .onTapGesture {
            if modelProvider.selectionIndex != index {
                modelProvider.selectionIndex = index
            } else {
                item.open(query: modelProvider.searchText)
            }
        }
        .contextMenu {
            Button("Open") {
                item.open(query: modelProvider.searchText)
            }
            Button("Show in Enclosing Folder") {
                item.reveal(query: modelProvider.searchText)
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
    SearchResultItem(index: 0, item: QueryItem.preview, match: Text("here"))
        .environment(ModelProvider.preview)
        .frame(width: 200)
}
