//
//  IconView.swift
//  SpotFile
//
//  Created by Vaida on 7/11/24.
//

import SwiftUI
import ViewCollection
import FinderItem


struct IconView: View {
    
    let item: any QueryItemProtocol
    
    let scale: Scale
    
    let isSelected: Bool
    
    var finderItem: FinderItem {
        item.item
    }
    
    @Environment(\.displayScale) private var displayScale
    
    
    var body: some View {
        Group {
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
                AsyncDrawnImage(generator: makePreview, frame: .square(scale.side))
                    .id(finderItem)
            }
        }
        .frame(width: scale.side, height: scale.side)
    }
    
    private nonisolated func makePreview() async -> CGImage? {
        try? await finderItem.preview(size: .square(scale.side * displayScale)).cgImage
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
