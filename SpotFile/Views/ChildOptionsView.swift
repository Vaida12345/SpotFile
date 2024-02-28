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
                        
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.5)
                                .offset(x: 5)
                        }
                        Button("Update") {
                            Task {
                                isUpdating = true
                                try await item.updateChildren()
                                isUpdating = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!options.isEnabled || isUpdating)
                    }
                    Text("When enabled, you can also search for contents of the folder by typing its name")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Divider()
                    
                    Group {
                        Text("Searches For")
                        
                        HStack {
                            Toggle("Folders", isOn: $options.includeFolder)
                                .disabled(!options.includeFile)
                            Toggle("Files", isOn: $options.includeFile)
                                .disabled(!options.includeFolder)
                        }
                        .padding(.bottom)
                        
                        Toggle("Enable enumeration", isOn: $options.enumeration)
                    }
                    .disabled(!options.isEnabled)
                    .modifier(enabled: !options.isEnabled) { view in
                        view.foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

#Preview {
    ChildOptionsView(item: .preview,
                     options: .constant(.init(isDirectory: true)))
        .padding(.all)
}
