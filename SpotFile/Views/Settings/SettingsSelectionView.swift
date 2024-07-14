//
//  SettingsSelectionView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/17.
//

import SwiftUI
import Stratum

struct SettingsSelectionView: View {
    
    let selection: QueryItem
    
    @State private var showFilePicker = false
    
    @AppStorage("SettingsSelectionView.showInspector") private var showInspector = false
    
    @FocusState private var focusedState: FocusValues?
    
    @Environment(ModelProvider.self) private var modelProvider: ModelProvider
    
    @Environment(\.undoManager) private var undoManager
    
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(\.modelContext) private var modelContext
    
    
    var body: some View {
        @Bindable var selection = selection
        let itemIsNew = selection.query.content == "new"
        
        DropHandlerView()
            .overlay(hidden: false) { isDropTargeted in
                ScrollView {
                    VStack {
                        HStack {
                            IconView(item: selection, scale: .small, isSelected: true)
                            
                            TextField("", text: $selection.query.content)
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
                                
                                TextField("The target location. Note: You can also drop in the file.", text: Binding<String> {
                                    if itemIsNew {
                                        ""
                                    } else {
                                        selection.item.description
                                    }
                                } set: {
                                    selection.item = FinderItem(at: $0)
                                })
                                .onSubmit {
                                    guard selection.item.exists else {
                                        AlertManager("The file does not exist", message: "Please paste your path again.").present()
                                        return
                                    }
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
                        .padding(.top)
                        .multilineTextAlignment(.trailing)
                        
                        VStack {
                            if selection.query.components.count > 1 {
                                GroupBox {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Toggle("Must include first keyword", isOn: $selection.query.mustIncludeFirstKeyword)
                                            Spacer()
                                        }
                                        if case let .content(content) = selection.query.components.first {
                                            Text("When conducting searches, the leading keyword *\(content)* must be included (or partially included) to find this item.")
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                }
                            }
                            
                            ChildOptionsView(item: selection, options: $selection.childOptions)
                        }
                        .padding(.vertical)
                        .multilineTextAlignment(.trailing)
                    }
                    .padding()
                    .buttonStyle(.plain)
                    .textFieldStyle(.plain)
                }
                .scrollIndicators(.never)
                .background(.background)
                .inspector(isPresented: $showInspector) {
                    SettingsSelectionInspector(selection: selection)
                }
                .overlay {
                    if isDropTargeted {
                        VStack {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .imageScale(.large)
                                .frame(width: 100, height: 100)
                                .bold()
                                .padding()
                            
                            Text("Drop the file here to set its location")
                                .fontDesign(.rounded)
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.all)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .onDrop { sources in
                guard let item = sources.first else { return }
                Task { @MainActor in
                    undoManager?.setActionName("Drop File")
                    await self.add(item: item)
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item, .folder]) { result in
                do {
                    let url = try result.get()
                    let item = FinderItem(at: url)
                    Task { @MainActor in
                        undoManager?.setActionName("Add File from File Importer")
                        await self.add(item: item)
                    }
                } catch {
                    AlertManager(error).present()
                }
            }
            .fileDialogDefaultDirectory(itemIsNew ? nil : selection.item.url)
            .onAppear {
                if itemIsNew {
                    self.focusedState = .title
                }
            }
            .toolbar {
                HStack {
                    Button {
                        modelProvider.remove(selection, from: \.items, undoManager: undoManager)
                        
                        withErrorPresented("Delete \"\(selection.query)\" encountered error") {
                            try modelContext.delete(model: QueryChildRecord.self, where: #Predicate { $0.parentID == selection.id })
                        }
                    } label: {
                        Image(systemName: "trash")
                            .symbolRenderingMode(.multicolor)
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                    
                    Divider()
                    
                    Button {
                        showInspector.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help("Additional controls")
                }
            }
    }
    
    enum FocusValues {
        case title
        case relativePath
        case overrideIcon
    }
    
    func add(item: FinderItem) async {
        self.selection.apply(undoManager: undoManager) { doc in
            doc.item = item
            doc.childOptions.isDirectory = item.isDirectory && !((try? item.fileType.contains(.package)) ?? false)
            
            if doc.query.content == "new" {
                doc.query.content = item.stem
            }
            
            let shouldReplaceIcon = !item.appending(path: "Icon\r").exists
            if !shouldReplaceIcon {
                doc.iconSystemName = ""
            }
            
            if let project = try? item.children(range: .contentsOfDirectory).onlyMatch(where: { $0.extension == "xcodeproj" }) {
                doc.openableFileRelativePath = project.relativePath(to: item) ?? ""
                if doc.query.content == "new" {
                    doc.query.content = project.stem
                }
                
                if shouldReplaceIcon {
                    doc.iconSystemName = "xcodeproj.fill"
                }
            } else if item.appending(path: "Package.swift").exists {
                doc.openableFileRelativePath = "Package.swift"
                
                if shouldReplaceIcon {
                    doc.iconSystemName = "shippingbox"
                }
            }
        }
    }
}

#Preview {
    SettingsSelectionView(selection: .preview)
        .environment(ModelProvider.preview)
}
