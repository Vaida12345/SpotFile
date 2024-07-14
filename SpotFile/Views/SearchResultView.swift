//
//  SearchResultView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/18.
//

import SwiftUI

struct SearchResultView: View {
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    var body: some View {
        VStack(spacing: 4) {
            if modelProvider.previous.parentQuery != nil {
                if let item = modelProvider.previous.matches.first {
                    HStack {
                        IconView(item: item, scale: .small, isSelected: false)
                        
                        Text(item.query.content)
                            .bold()
                        Spacer()
                    }
                    .padding(.leading, 7.5)
                }
                
                Divider()
            }
            
            if modelProvider.matches.isEmpty {
                Group {
                    if modelProvider.isSearching {
                        Text("Loading...")
                    } else {
                        Text("No result found")
                    }
                }
                .bold()
                .foregroundStyle(.secondary)
                .fontDesign(.rounded)
                .padding()
                .frame(maxWidth: .infinity)
            } else {
                let values = if modelProvider.shownStartIndex == 0 {
                    modelProvider.matches.prefix(25)
                } else {
                    modelProvider.matches.dropFirst(max(0, min(modelProvider.matches.count - 25, modelProvider.shownStartIndex))).prefix(25)
                }
                
                ForEach(values, id: \.1.id) { (index, item, match) in
                    SearchResultItem(index: index, item: item, match: match)
                }
                
                if modelProvider.matches.count > 25 {
                    Group {
                        Divider()
                        Text("\(modelProvider.matches.count - 25) more items")
                    }
                }
                
            }
        }
        .padding(.vertical, 2.5)
    }
}

#Preview {
    SearchResultView()
        .frame(width: 200)
        .environment(ModelProvider.preview)
}
