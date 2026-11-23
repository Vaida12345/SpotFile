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
        
        DispatchQueue.main.async {
            searchField.window?.makeKeyAndOrderFront(nil)
            searchField.becomeFirstResponder()
        }
        
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
        
        // Never replace the text while it is being edited: the field editor keeps its insertion point, so keystrokes in flight would be inserted at the wrong place. The coordinator edits the field directly instead. Clearing the field (reset) is always safe.
        if searchField.currentEditor() == nil || modelProvider.searchText.isEmpty,
           searchField.stringValue != modelProvider.searchText {
            searchField.stringValue = modelProvider.searchText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(modelProvider: modelProvider, context: context)
    }
}
