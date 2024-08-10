//
//  ChildOptionsView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import SwiftUI
import Stratum

struct ChildOptionsView: View {
    
    let item: QueryItem
    
    @Binding var options: QueryItem.ChildOptions
    
    @State private var isUpdating = false
    
    @FocusState private var isFocused: Bool
    @FocusState private var isRelativePathFocused: Bool
    
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
                        
                        Text("If enabled, contents of subfolders, and so on will be included.")
                            .foregroundStyle(!options.isEnabled ? .tertiary : .secondary)
                        
                        HStack {
                            Text("Filter By")
                            
                            TextField(#"/.*∖.app/, /.*∖.txt/"#, text: $options.filterBy)
                                .multilineTextAlignment(.trailing)
                                .padding(.trailing, 5)
                                .fontDesign(.monospaced)
                                .onSubmit {
                                    updateFiltersRegex()
                                }
                                .focused($isFocused)
                                .onChange(of: isFocused) {
                                    updateFiltersRegex()
                                }
                        }
                        .padding(.top)
                        
                        Text("Please enter filters in Regex, including the slashes")
                            .foregroundStyle(!options.isEnabled ? .tertiary : .secondary)
                        
                        HStack {
                            Text("Relative Path")
                            
                            TextField("The relative path to the location of the child (Regex supported).", text: $options.plainRelativePath)
                                .multilineTextAlignment(.trailing)
                                .focused($isRelativePathFocused)
                                .onSubmit {
                                    updateRelativePathRegex()
                                }
                                .onChange(of: isRelativePathFocused) {
                                    updateRelativePathRegex()
                                }
                        }
                        .padding(.top)
                        
                        Text("The relative path to open. When not exist, the file / folder would be opened / shown.")
                            .foregroundStyle(!options.isEnabled ? .tertiary : .secondary)
                    }
                    .disabled(!options.isEnabled)
                    .modifier(enabled: !options.isEnabled) { view in
                        view.foregroundStyle(.tertiary)
                    }
                }
                .multilineTextAlignment(.leading)
                .textFieldStyle(.plain)
            }
        }
    }
    
    private func updateRelativePathRegex() {
        do {
            try options.updateRelativePath()
        } catch {
            options.plainRelativePath = ""
            AlertManager("Regex Parse Error", message: "Please check your regex expression. The changes were discarded. The error is: \("\(error)")").present()
        }
    }
    
    private func updateFiltersRegex() {
        do {
            try options.updateFilters()
        } catch {
            self.options.filterBy = ""
            AlertManager("Regex Parse Error", message: "Please check your regex expression. The changes were discarded. The error is: \("\(error)")").present()
        }
    }
}

#Preview {
    ChildOptionsView(item: .preview,
                     options: .constant(QueryItem.ChildOptions(isDirectory: true, isEnabled: true)))
        .padding(.all)
}
