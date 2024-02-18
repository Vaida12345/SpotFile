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
    
    let item: QueryItem
    
    let match: AttributedString
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    
    @State private var hovering = false
    
    
    var body: some View {
        HStack {
            item.iconView
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            
            Text(match)
            
            Spacer()
            
            if hovering {
                Button {
                    withErrorPresented {
                        try item.item.reveal()
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
            }
        }
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
                withErrorPresented {
                    try item.item.reveal()
                }
            }
            
            Divider()
            
            
        }
    }
}

#Preview {
    SearchResultItem(index: 0, item: .preview, match: AttributedString("here"))
        .environment(ModelProvider.preview)
        .frame(width: 200)
}
