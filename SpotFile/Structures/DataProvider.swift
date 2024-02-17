//
//  DataProvider.swift
//  The Nucleus Module
//
//  Created by Vaida on 6/13/22.
//  Copyright © 2019 - 2023 Vaida. All rights reserved.
//


import Foundation
import SwiftData


/// The provider for the main storable workflow of data.
///
/// - Important: Do not inherit from this protocol directly, use the ``dataProviding()`` macro.
///
/// Create a `final class` that inherits from this protocol.
///
/// ```swift
/// @dataProviding
/// @Obsersable
/// final class Provider {
///     var stories: [Story] = []
/// }
/// ```
///
/// The loading and saving progress is automated, where the file is loaded on setup, and saved when the app enters background.
public protocol DataProvider: Codable, Identifiable {
    
    /// The main ``DataProvider`` to work with.
    ///
    /// In the `@main App` declaration, declare a `StateObject` of `instance`. In this way, this structure can be accessed across the app, and any mutation is observed in all views.
    static var instance: Self { get set }
    
}


extension DataProvider {
    
    /// The path indicating the location where this ``DataProvider`` is persisted on disk.
    @inlinable
    public static var storageLocation: URL {
        URL(filePath: NSHomeDirectory() + "/Library/Application Support/DataProviders/\(Self.self).plist", directoryHint: .notDirectory)
    }
    
    /// Save the encoded provider to ``storageItem`` using `.plist`.
    @inlinable
    public func save() throws {
        if FileManager.default.fileExists(atPath: Self.storageLocation.path) {
            try FileManager.default.removeItem(at: Self.storageLocation)
        }
        try FileManager.default.createDirectory(at: Self.storageLocation.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(self).write(to: Self.storageLocation)
    }
    
}
