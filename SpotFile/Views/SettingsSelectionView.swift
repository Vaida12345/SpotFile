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
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    @Environment(\.undoManager) private var undoManager
    
    
    var body: some View {
        DropHandlerView()
            .overlay(hidden: false) { isDropTargeted in
                ScrollView {
                    VStack {
                        HStack {
                            selection.iconView
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
                                    if case let .content(content) = selection.queryComponents.first {
                                        Text("When conducting searches, the leading keyword *\(content)* must be included to find this item.")
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
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
                Task { @MainActor in
                    await self.add(item: item)
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
                do {
                    let url = try result.get()
                    let item = FinderItem(at: url)
                    Task { @MainActor in
                        await self.add(item: item)
                    }
                } catch {
                    AlertManager(error).present()
                }
            }
            .onAppear {
                if selection.query == "new" {
                    self.focusedState = .title
                }
            }
            .toolbar {
                Button {
                    try? selection.delete()
                    modelProvider.removeAll(from: \.items, undoManager: undoManager) {
                        $0.id == selection.id
                    }
                } label: {
                    Image(systemName: "trash")
                        .symbolRenderingMode(.multicolor)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }
    }
    
    enum FocusValues {
        case title
        case relativePath
        case overrideIcon
    }
    
    func add(item: FinderItem) async {
        self.selection.item = item
        try? await self.selection.updateIcon()
        
        if self.selection.query == "new" {
            self.selection.query = item.stem
        }
        
        let shouldReplaceIcon = !((try? await item.children(range: .contentsOfDirectory.withSystemHidden).contains(where: { $0.name == "Icon\r" })) ?? false)
        
        if let project = try? await item.children(range: .contentsOfDirectory).onlyMatch(where: { $0.extension == "xcodeproj" }) {
            self.selection.openableFileRelativePath = project.relativePath(to: item) ?? ""
            self.selection.query = project.stem
            
            if shouldReplaceIcon {
                self.selection.iconSystemName = "xcodeproj"
            }
        } else if item.appending(path: "Package.swift").exists {
            self.selection.openableFileRelativePath = "Package.swift"
            
            if shouldReplaceIcon {
                self.selection.iconSystemName = "shippingbox"
            }
        }
    }
}

#Preview {
    SettingsSelectionView(selection: .preview)
}
