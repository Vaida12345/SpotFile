//
//  Icon.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import Foundation
import Stratum


/// An icon, remember to resize the icon to 32 x 32
@Observable
final class Icon: Codable {
    
    var image: NativeImage? {
        didSet {
            isUpdated = true
            Task.detached {
                try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons").appending(path: "\(self.id).heic").removeIfExists()
            }
        }
    }
    
    @ObservationIgnored
    var isUpdated: Bool = false
    
    let id: UUID
    
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        guard image != nil else { try container.encodeNil(); return }
        try container.encode(id)
        
        guard isUpdated else { return }
        
        let iconDir = FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons")
        try image?.write(to: iconDir.appending(path: "\(id).heic"), option: .heic)
        self.isUpdated = false
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard !container.decodeNil() else {
            self.id = UUID()
            return
        }
        let id = try container.decode(UUID.self)
        guard let image = NativeImage(at: FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons").appending(path: "\(id).heic")) else { throw ErrorManager("Cannot decode the image") }
        self.image = image
        self.id = id
    }
    
    init(image: NativeImage?) {
        self.image = image
        self.id = UUID()
    }
    
    static let preview = Icon(image: NativeImage())
}
