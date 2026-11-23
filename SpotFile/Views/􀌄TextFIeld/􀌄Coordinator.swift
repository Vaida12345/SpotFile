//
//  TextFIeld + Coordinator.swift
//  SpotFile
//
//  Created by Vaida on 2025-07-05.
//

import AppKit
import SwiftData
import Combine


extension SuggestionTextField {
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        
        let modelProvider: ModelProvider
        let context: ModelContext
        
        let fileSearcher: FileSearcher
        
        var cancellables: Set<AnyCancellable> = []
        
        init(modelProvider: ModelProvider, context: ModelContext) {
            self.modelProvider = modelProvider
            self.context = context
            
            self.fileSearcher = FileSearcher()
            super.init()
            
            self.fileSearcher.createPublisher(context: context)
                .receive(on: RunLoop.main)
                .sink { [weak self] result in
                    MainActor.assumeIsolated {
                        self?.receive(result)
                    }
                }
                .store(in: &cancellables)
            
            self.fileSearcher.isSearching
                .receive(on: RunLoop.main)
                .sink { newValue in
                    MainActor.assumeIsolated {
                        modelProvider.isSearching = newValue
                    }
                }
                .store(in: &cancellables)
        }
        
        var searchField: NSSearchField!

        /// The text in the search field, including any edit in progress.
        private var fieldText: String {
            (searchField.currentEditor() as? NSTextView)?.string ?? searchField.stringValue
        }

        /// Removes the first `count` characters from the search field.
        ///
        /// While editing, this edits the field editor in place, so the insertion point and any keystrokes typed after the removed range are kept.
        @MainActor
        private func removeFieldPrefix(count: Int) {
            if let editor = searchField.currentEditor() as? NSTextView {
                let string = editor.string
                let end = string.index(string.startIndex, offsetBy: count)
                editor.replaceCharacters(in: NSRange(string.startIndex..<end, in: string), with: "")
            } else {
                searchField.stringValue.removeFirst(count)
            }
            modelProvider.searchText = fieldText
        }

        @MainActor
        private func receive(_ result: FileSearcher.SearchState) {
            let text = self.fieldText
            let isSameParent = result.request.parent?.id == modelProvider.deepSearchTarget?.id

            // A deep search that picks a new target from the typed text. Accept it even if the user has typed more since, as long as the field still starts with what was searched: stripping the target query is still correct then.
            if case let .deep(target, parentQuery?, matches) = result.match,
               result.request.parent == nil, modelProvider.deepSearchTarget == nil,
               text.hasPrefix(result.request.text), parentQuery.count <= text.count, text.lowercased().hasPrefix(parentQuery) {
                fileSearcher.commit(result)

                modelProvider.matches = matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                modelProvider.deepSearchTarget = target
                removeFieldPrefix(count: parentQuery.count)

                if result.request.text != text {
                    // The user has typed more, search again for the rest within the target.
                    fileSearcher.sendSearchRequest(modelProvider.searchText, parent: target)
                }
                return
            }

            guard result.request.text == text, isSameParent else {
                return  // this is from an old result, ignore.
            }

            fileSearcher.commit(result)

            if result.options.contains(.reset) {
                modelProvider.reset()
            } else {
                switch result.match {
                case .direct(let matches):
                    modelProvider.matches = matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                    modelProvider.deepSearchTarget = nil

                case .deep(let target, _, let matches):
                    modelProvider.matches = matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                    modelProvider.deepSearchTarget = target

                case .goto(let goto, let match):
                    modelProvider.matches = [(0, goto, match)]
                    modelProvider.deepSearchTarget = nil

                default:
                    break
                }
            }
        }

        // MARK: - NSSearchField Delegate Methods
        
        func controlTextDidChange(_ notification: Notification) {
            let text = self.searchField.stringValue
            
            modelProvider.searchText = text
            fileSearcher.sendSearchRequest(text, parent: modelProvider.deepSearchTarget)
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            Task {
                await modelProvider.submitItem(context: context)
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if modelProvider.selectionIndex > 0 {
                    modelProvider.selectionIndex -= 1
                    if modelProvider.selectionIndex - modelProvider.shownStartIndex < 0 {
                        modelProvider.shownStartIndex -= 1
                    }
                }
                return true // always consume
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if modelProvider.selectionIndex < modelProvider.matches.count - 1 {
                    modelProvider.selectionIndex += 1
                    if modelProvider.selectionIndex - modelProvider.shownStartIndex >= 25 {
                        modelProvider.shownStartIndex += 1
                    }
                    
                }
                return true // always consume
            } else if commandSelector == #selector(NSResponder.complete(_:)) ||
                        commandSelector == #selector(NSResponder.cancelOperation(_:)) ||
                        commandSelector == #selector(NSResponder.deleteToBeginningOfLine(_:)) {
                modelProvider.reset()
                fileSearcher.reset()
                
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                Task {
                    await modelProvider.submitItem(context: context)
                }
                
                return true
            } else if commandSelector == #selector(NSResponder.insertTab(_:)), modelProvider.selectionIndex < modelProvider.matches.count {
                let selection = modelProvider.matches[modelProvider.selectionIndex]
                if let item = selection.1 as? QueryItem {
                    // Set the field directly, as `updateNSView` does not write to the field while it is being edited.
                    searchField.stringValue = " "
                    modelProvider.searchText = " "
                    modelProvider.deepSearchTarget = item
                    fileSearcher.sendSearchRequest(" ", parent: item)
                }
                
                return true
            } else {
                return false
            }
        }
    }
    
}
