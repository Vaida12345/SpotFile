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
            VStack(spacing: 4) {
                ForEach(modelProvider.matches.prefix(25), id: \.1.id) { (index, item, match) in
                    SearchResultItem(index: index, item: item, match: match)
                }
                
                if modelProvider.matches.count > 25 {
                    Group {
                        Divider()
                        Text("\(modelProvider.matches.count - 25) more items")
                    }
                    .background(.thickMaterial)
                }
            }
            .padding(.vertical, 2.5)
        }
    }
}

#Preview {
    SearchResultView()
        .frame(width: 200)
        .environment(ModelProvider.preview)
}
