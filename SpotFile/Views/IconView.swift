//
//  IconView.swift
//  SpotFile
//
//  Created by Vaida on 7/11/24.
//

import SwiftUI
import ViewCollection


struct IconView: View {
    
    let item: any QueryItemProtocol
    
    let scale: Scale
    
    let isSelected: Bool
    
    @Environment(\.displayScale) private var displayScale
    
    
    var body: some View {
        if !item.iconSystemName.isEmpty {
            if item.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? .white : .blue)
            } else if item.iconSystemName == "xcodeproj.fill" {
                Image(.xcodeprojFill)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? .white : .blue)
            } else {
                Image(systemName: item.iconSystemName)
            }
        } else {
            AsyncView(generator: makePreview) { result in
                AsyncDrawnImage(nativeImage: result, frame: .square(scale.side))
            }
            .id(item.item)
        }
    }
    
    private nonisolated func makePreview() async throws -> NSImage {
        try await item.item.preview(size: .square(scale.side * displayScale))
    }
    
    
    enum Scale {
        case small
        case large
        
        var side: CGFloat {
            switch self {
            case .small:
                20
            case .large:
                50
            }
        }
    }
}
