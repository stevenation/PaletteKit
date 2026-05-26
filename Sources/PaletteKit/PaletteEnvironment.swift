//
//  PaletteEnvironment.swift
//  PaletteKit
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

import SwiftUI

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: ImagePalette = .placeholder
}

extension EnvironmentValues {
    public var palette: ImagePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
