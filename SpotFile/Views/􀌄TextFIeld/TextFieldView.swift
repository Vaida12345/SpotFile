//
//  TextFieldView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/18.
//

import Foundation
import AppKit
import SwiftUI
import SwiftData


// original code from https://developer.apple.com/library/archive/samplecode/CustomMenus

struct SuggestionTextField: NSViewRepresentable {
    
    @Binding var isFirstResponder: Bool
    
    let modelProvider: ModelProvider
    let context: ModelContext
    
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.maximumRecents = 0
        searchField.controlSize = .regular
        searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: searchField.controlSize))
        searchField.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(rawValue: 1), for: .horizontal)
        searchField.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 1), for: .horizontal)
        searchField.delegate = context.coordinator
        searchField.isSelectable = true
        searchField.isEditable = true
        
        let searchFieldCell = searchField.cell!
        searchFieldCell.lineBreakMode = .byWordWrapping
        
        context.coordinator.searchField = searchField
        
        return searchField
    }
    
    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if isFirstResponder, searchField.window?.firstResponder == nil {
            DispatchQueue.main.async {
                searchField.window?.makeKeyAndOrderFront(nil)
                searchField.becomeFirstResponder()
            }
        }
        
        if let prefix = modelProvider.previous.parentQuery,
            modelProvider.searchText.hasPrefix(prefix) {
            let pendingUpdate = String(modelProvider.searchText.dropFirst(prefix.count))
            if searchField.stringValue != pendingUpdate {
                searchField.stringValue = pendingUpdate
            }
        } else {
            if searchField.stringValue != modelProvider.searchText {
                searchField.stringValue = modelProvider.searchText
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(modelProvider: modelProvider, context: context)
    }
}
