//
//  ImagePalette.swift
//  PaletteKit
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

import SwiftUI

// Internal Sendable color representation — never exposed publicly.
struct RGB: Sendable, Equatable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r, green: g, blue: b) }
}

public struct ImagePalette: Sendable, Equatable {
    private let _dominant: RGB
    private let _vibrant: RGB
    private let _muted: RGB
    private let _dark: RGB
    private let _light: RGB

    public let foreground: Color
    public let secondaryForeground: Color
    public let accent: Color

    public var dominant: Color { _dominant.color }
    public var vibrant: Color { _vibrant.color }
    public var muted: Color { _muted.color }
    public var dark: Color { _dark.color }
    public var light: Color { _light.color }

    // Internal accessors for tests via @testable import.
    var dominantRGB: RGB { _dominant }
    var vibrantRGB: RGB { _vibrant }
    var mutedRGB: RGB { _muted }
    var darkRGB: RGB { _dark }
    var lightRGB: RGB { _light }

    init(
        dominant: RGB, vibrant: RGB, muted: RGB, dark: RGB, light: RGB,
        foreground: Color, secondaryForeground: Color, accent: Color
    ) {
        _dominant = dominant
        _vibrant = vibrant
        _muted = muted
        _dark = dark
        _light = light
        self.foreground = foreground
        self.secondaryForeground = secondaryForeground
        self.accent = accent
    }

    public static let placeholder = ImagePalette(
        dominant: RGB(r: 0.5, g: 0.5, b: 0.5),
        vibrant: RGB(r: 0.6, g: 0.6, b: 0.6),
        muted: RGB(r: 0.45, g: 0.45, b: 0.45),
        dark: RGB(r: 0.2, g: 0.2, b: 0.2),
        light: RGB(r: 0.8, g: 0.8, b: 0.8),
        foreground: .primary,
        secondaryForeground: .secondary,
        accent: .accentColor
    )
}
