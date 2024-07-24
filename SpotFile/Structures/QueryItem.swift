//
//  QueryItem.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import Foundation
import Stratum
import SwiftUI
import StratumMacros
import SwiftData


@Observable
@codable
final class QueryItem: Codable, Identifiable, QueryItemProtocol, CustomStringConvertible {
    
    var id: UUID
    
    var query: Query
    
    var item: FinderItem
    
    var openableFileRelativePath: String
    
    /// If empty, use finder preview.
    var iconSystemName: String = ""
    
    
    @ObservationIgnored
    var openedRecords: [String: Int] = [:]
    
    var childOptions: ChildOptions = .init()
    
    var additionalQueries: [Query] = []
    
    
    // MARK: - Handling matches
    
    func updateRecords(_ query: String, context: ModelContext) {
        self.openedRecords[query, default: 0] += 1
    }
    
    func match(query: String) -> QueryItem.Match? {
        if let match = self.query.match(query: query, isChild: false) {
            return Match(text: match, isPrimary: true)
        }
        
        for additionalQuery in additionalQueries {
            if let match = additionalQuery.match(query: query, isChild: true) {
                return Match(text: match, isPrimary: false)
            }
        }
        
        return nil
    }
    
    func copy() -> QueryItem {
        QueryItem(id: self.id, query: self.query, item: item, openableFileRelativePath: openableFileRelativePath, iconSystemName: iconSystemName, openedRecords: openedRecords, childOptions: childOptions, additionalQueries: additionalQueries)
    }
    
    func copy(from source: QueryItem) {
        self.id = source.id
        self.query = source.query
        self.item  = source.item
        self.openableFileRelativePath  = source.openableFileRelativePath
        self.iconSystemName  = source.iconSystemName
        self.openedRecords  = source.openedRecords
        self.childOptions  = source.childOptions
        self.additionalQueries  = source.additionalQueries
    }
    
    
    struct Match: CustomStringConvertible, Equatable {
        
        let text: Text
        
        /// Whether the primary name is matched, instead of alternative names.
        let isPrimary: Bool
        
        
        var description: String {
            let regex = /(?:SwiftUI\.)?Text\(storage: SwiftUI\.Text\.Storage\.anyTextStorage\(.*?: "(.*?)"\), modifiers: \[\]\)/
            if let match = "\(self.text)".wholeMatch(of: regex) {
                return String(match.output.1)
            } else {
                return "\(self.text)"
            }
        }
        
    }
    
    
    // MARK: - Initializers, static values
    
    init(query: String, item: FinderItem, openableFileRelativePath: String) {
        self.id = UUID()
        self.query = Query(value: query)
        self.item = item
        self.openableFileRelativePath = openableFileRelativePath
    }
    
    static let separators: [Character] = ["_", "/"]
    
    static var preview: QueryItem {
        QueryItem(query: "swift testRoom",
                  item: FinderItem(at: "/Users/vaida/Library/Mobile Documents/com~apple~CloudDocs/DataBase/Swift/testRoom/testRoom"),
                  openableFileRelativePath: "testRoom/folder/testRoom.xcodeproj")
    }
    
    static func new() -> QueryItem {
        QueryItem(query: "new", item: .homeDirectory, openableFileRelativePath: "")
    }
    
    func set<T>(_ keyPath: ReferenceWritableKeyPath<QueryItem, T>, to newValue: T, undoManager: UndoManager?) {
        let oldValue = self[keyPath: keyPath]
        
        self[keyPath: keyPath] = newValue
        
        undoManager?.registerUndo(withTarget: self) { object in
            object[keyPath: keyPath] = oldValue
        }
    }
    
    func apply(undoManager: UndoManager?, action: (_ doc: QueryItem) -> Void) {
        let oldCopy = self.copy()
        action(self)
        
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.replace(with: oldCopy, undoManager: undoManager)
        }
    }
    
    func replace(with copy: QueryItem, undoManager: UndoManager?) {
        let oldCopy = self.copy()
        self.copy(from: copy)
        
        undoManager?.setActionName("Replace Item")
        
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.replace(with: oldCopy, undoManager: undoManager)
        }
    }
    
    var description: String {
        "QueryItem<query: \(self.query)>"
    }
}
