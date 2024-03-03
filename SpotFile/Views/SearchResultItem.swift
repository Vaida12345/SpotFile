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
    
    let match: Text
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    @Environment(\.colorScheme) private var colorScheme
    
    
    @State private var hovering = false
    
    @State private var showPopover = false
    
    @State private var updatePopoverTask: Task<Void, any Error> = Task { }
    
    
    @ViewBuilder
    var help: some View {
        if !item.openableFileRelativePath.isEmpty,
           let name = item.openableFileRelativePath.components(separatedBy: "/").last,
           let _item = modelProvider.previous.matches.first,
           let relative = item.item.relativePath(to: _item.item) {
            let folder = relative.dropLast(name.count + 1)
            if folder.isEmpty {
                Text(name)
            } else {
                VStack(alignment: .leading) {
                    Text(name)
                        .fontWeight(.semibold)
                    Text(folder)
                }
            }
        } else {
            Text(item.openableFileRelativePath)
        }
    }
    
    
    var body: some View {
        HStack {
            Group {
                if let item = item as? QueryItem {
                    item.smallIconView(isSelected: index == modelProvider.selectionIndex)
                } else if let item = item as? QueryItemChild {
                    AsyncView {
                        try await item.item.preview(size: .square(20))
                    } content: { value in
                        Image(nativeImage: value)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }

                } else {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 20, height: 20)
            
            if index == modelProvider.selectionIndex && item is QueryItemChild {
                help
            } else {
                match
                    .lineLimit(1)
            }
            
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
        .onChange(of: index == modelProvider.selectionIndex) { oldValue, newValue in
            if newValue {
                updatePopoverTask = Task {
                    guard item is QueryItemChild else { return }
                    try await Task.sleep(for: .seconds(0.5))
                    
                    Task { @MainActor in
                        showPopover = true
                    }
                }
            } else {
                updatePopoverTask.cancel()
                showPopover = false
            }
        }
        .foregroundStyle(index == modelProvider.selectionIndex ? .white : .primary)
        .padding(.vertical, 5)
        .padding(.leading, 7)
        .frame(maxWidth: .infinity)
        .frame(height: index == modelProvider.selectionIndex && item is QueryItemChild ? nil : 25)
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
