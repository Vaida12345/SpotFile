//
//  SettingsSelectionView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/17.
//

import SwiftUI
import Stratum

struct SettingsSelectionView: View {
    
    @Bindable var selection: QueryItem
    
    @State private var showFilePicker = false
    
    @FocusState private var focusedState: FocusValues?
    
    var icon: Image {
        if let image = selection.icon.image {
            Image(nsImage: image)
        } else if !selection.iconSystemName.isEmpty {
            Image(systemName: selection.iconSystemName)
        } else {
            Image(systemName: "folder.badge.plus")
        }
    }
    
    var body: some View {
        DropHandlerView()
            .overlay(hidden: false) { isDropTargeted in
                ScrollView {
                    VStack {
                        HStack {
                            icon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                            
                            TextField("", text: $selection.query)
                                .font(.title)
                                .bold()
                                .textSelection(.enabled)
                                .focused($focusedState, equals: .title)
                                .onSubmit {
                                    focusedState = .relativePath
                                }
                        }
                        
                        VStack {
                            HStack {
                                Text("Location")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                TextField("Location", text: Binding<String> {
                                    selection.item.userFriendlyDescription
                                } set: {
                                    selection.item = FinderItem(at: $0)
                                })
                                .onSubmit {
                                    focusedState = .relativePath
                                }
                                
                                Button("Browse...") {
                                    showFilePicker = true
                                }
                                .foregroundStyle(Color.accentColor)
                            }
                            
                            HStack {
                                Text("Relative Path")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                TextField("The executable's relative path to the *location* above", text: $selection.openableFileRelativePath)
                                    .focused($focusedState, equals: .relativePath)
                                    .onSubmit {
                                        focusedState = .overrideIcon
                                    }
                            }
                        }
                        .padding(.vertical)
                        .multilineTextAlignment(.trailing)
                        
                        VStack {
                            HStack {
                                Text("Override Icon")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                TextField("An optional name of SF Symbol to be used as icon", text: $selection.iconSystemName)
                                    .focused($focusedState, equals: .overrideIcon)
                                    .onSubmit {
                                        focusedState = nil
                                    }
                            }
                            .padding(.bottom)
                            
                            GroupBox {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Toggle("Must include first keyword", isOn: $selection.mustIncludeFirstKeyword)
                                        Spacer()
                                    }
                                    Text("When conducting searches, the leading keyword *\(selection.queryComponents.first?.value ?? "")* must be included to find this item.")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical)
                        .multilineTextAlignment(.trailing)
                    }
                    .padding()
                    .buttonStyle(.plain)
                    .textFieldStyle(.plain)
                }
                .background {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 1)
                    }
                }
            }
            .onDrop { sources in
                guard let item = sources.first else { return }
                self.selection.item = item
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
                do {
                    let url = try result.get()
                    self.selection.item = FinderItem(at: url)
                } catch {
                    AlertManager(error).present()
                }
            }
            .onAppear {
                if selection.query == "new" {
                    self.focusedState = .title
                }
            }
    }
    
    enum FocusValues {
        case title
        case relativePath
        case overrideIcon
    }
}

#Preview {
    SettingsSelectionView(selection: .preview)
}
