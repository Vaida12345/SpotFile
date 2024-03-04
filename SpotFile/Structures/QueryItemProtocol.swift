//
//  QueryItemProtocol.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//


import SwiftUI
import Stratum
import ViewCollection


protocol QueryItemProtocol: AnyObject, UndoTracking {
    
    var id: UUID { get }
    
    var query: Query { get }
    
    var item: FinderItem { get }
    
    var openableFileRelativePath: String { get }
    
    var iconSystemName: String { get }
    
    func updateRecords(_ query: String)
    
}


extension QueryItemProtocol {
    
    // MARK: - Views
    
    @ViewBuilder
    func smallIconView(isSelected: Bool) -> some View {
        if !self.iconSystemName.isEmpty {
            if self.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? .white : .blue)
            } else if self.iconSystemName == "xcodeproj.fill" {
                Image(.xcodeprojFill)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? .white : .blue)
            } else {
                Image(systemName: self.iconSystemName)
            }
        } else {
            AsyncView {
                try await self.item.preview(size: .square(64))
            } content: { result in
                Image(nativeImage: result)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .id(self.item)
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        if !self.iconSystemName.isEmpty {
            let image = if self.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
            } else if self.iconSystemName == "xcodeproj.fill" {
                Image(.xcodeprojFill)
            } else {
                Image(systemName: self.iconSystemName)
            }
            
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
        } else {
            AsyncView {
                try await self.item.preview(size: .square(128))
            } content: { result in
                Image(nativeImage: result)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .id(self.item)
            .frame(width: 50, height: 50)
        }
    }
    
    
    // MARK: - Handling matches
    
    func match(query: String) -> QueryItem.Match? {
        if let match = self.query.match(query: query) {
            return QueryItem.Match(text: match, isPrimary: true)
        }
        
        return nil
    }
    
    
    // MARK: - File Operations
    
    func reveal(query: String) {
        updateRecords(query)
        withErrorPresented {
            let path = item
            try path.reveal()
            postSubmitAction()
        }
    }
    
    func open(query: String) {
        updateRecords(query)
        let item = self.item
        let openableFileRelativePath = self.openableFileRelativePath
        Task {
            await withErrorPresented {
                let path = if self is QueryItem {
                    item.appending(path: openableFileRelativePath)
                } else {
                    item
                }
                try await path.open()
                postSubmitAction()
            }
        }
    }
}


private let emphasizedAttributeContainer = {
    var container = AttributeContainer()
    container.inlinePresentationIntent = .stronglyEmphasized
    return container
}()

func postSubmitAction() {
    Task { @MainActor in
        NSApp.hide(nil)
        ModelProvider.instance.searchText = ""
    }
    
    Task.detached {
        try ModelProvider.instance.save()
    }
}
