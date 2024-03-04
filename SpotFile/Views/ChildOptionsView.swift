//
//  ChildOptionsView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import SwiftUI

struct ChildOptionsView: View {
    
    let item: QueryItem
    
    @Binding var options: QueryItem.ChildOptions
    
    @State private var isUpdating = false
    
    var body: some View {
        if options.isDirectory {
            GroupBox {
                VStack(alignment: .leading) {
                    HStack {
                        Toggle("Enable deep search", isOn: $options.isEnabled)
                        Spacer()
                    }
                    Text("When enabled, you can also search for contents of the folder by typing its name")
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    Group {
                        Text("Searches For")
                        
                        HStack {
                            Toggle("Folders", isOn: $options.includeFolder)
                                .disabled(!options.includeFile)
                            Toggle("Files", isOn: $options.includeFile)
                                .disabled(!options.includeFolder)
                        }
                        
                        Text("Define what kind of files should be included in search results.")
                            .foregroundStyle(!options.isEnabled ? .tertiary : .secondary)
                            .padding(.bottom)
                        
                        Toggle("Enable enumeration", isOn: $options.enumeration)
                        
                        Text("If enabled, contents of subfolders, and so on will be included. Note that large folders will cause the app laggy.")
                            .foregroundStyle(!options.isEnabled ? .tertiary : .secondary)
                    }
                    .disabled(!options.isEnabled)
                    .modifier(enabled: !options.isEnabled) { view in
                        view.foregroundStyle(.tertiary)
                    }
                }
                .multilineTextAlignment(.leading)
            }
        }
    }
}

#Preview {
    ChildOptionsView(item: .preview,
                     options: .constant(.init(isDirectory: true)))
        .padding(.all)
}
