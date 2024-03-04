//
//  SettingsSelectionInspector.swift
//  SpotFile
//
//  Created by Vaida on 2024/3/4.
//

import SwiftUI

struct SettingsSelectionInspector: View {
    
    @Bindable var selection: QueryItem
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                Group {
                    Text("Override Icon")
                        .fontWeight(.medium)
                    
                    TextField("An optional SF Symbol used as icon", text: $selection.iconSystemName)
                }
                
                HStack {
                    Text("Additional names")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button {
                        selection.append(Query(value: "new"), to: \.additionalQueries, undoManager: undoManager)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                .padding(.top)
            }
            .padding([.horizontal, .top])
            
            List($selection.additionalQueries) { query in
                TextField("name", text: query.content)
                    .contextMenu {
                        Toggle("Must include first keyword", isOn: query.mustIncludeFirstKeyword)
                        
                        Divider()
                        
                        Button("Remove") {
                            selection.remove(query.wrappedValue, from: \.additionalQueries, undoManager: undoManager)
                        }
                    }
                    .padding(.vertical, 2.5)
            }
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)
            .tableStyle(.inset)
            .alternatingRowBackgrounds(.disabled)
        }
        .textFieldStyle(.plain)
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsSelectionInspector(selection: .preview)
        .frame(width: 200)
}
