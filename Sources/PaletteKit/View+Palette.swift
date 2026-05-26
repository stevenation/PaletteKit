//
//  View+Palette.swift
//  PaletteKit
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Public modifiers

extension View {
#if canImport(UIKit)
    /// Extracts a semantic palette from `image` and injects it into the environment.
    public func extractPalette(from image: UIImage?) -> some View {
        modifier(PaletteModifier(image: image?.cgImage))
    }
#elseif canImport(AppKit)
    /// Extracts a semantic palette from `image` and injects it into the environment.
    public func extractPalette(from image: NSImage?) -> some View {
        let cgImage: CGImage? = image.flatMap { img in
            var rect = CGRect(origin: .zero, size: img.size)
            return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return modifier(PaletteModifier(image: cgImage))
    }
#endif

    /// Downloads the image at `url`, extracts a semantic palette, and injects it into the environment.
    public func extractPalette(from url: URL?) -> some View {
        modifier(URLPaletteModifier(url: url))
    }
}

// MARK: - PaletteModifier

@MainActor
struct PaletteModifier: ViewModifier {
    let image: CGImage?

    @State private var palette: ImagePalette = .placeholder
    private let extractor = PaletteExtractor()

    func body(content: Content) -> some View {
        content
            .environment(\.palette, palette)
            .task(id: image.map { ObjectIdentifier($0) }) {
                guard let cgImage = image else {
                    palette = .placeholder
                    return
                }
                let extracted = await extractor.extract(from: cgImage)
                palette = extracted
            }
    }
}

// MARK: - URLPaletteModifier

@MainActor
struct URLPaletteModifier: ViewModifier {
    let url: URL?

    @State private var palette: ImagePalette = .placeholder
    private let extractor = PaletteExtractor()

    func body(content: Content) -> some View {
        content
            .environment(\.palette, palette)
            .task(id: url) {
                guard let url else {
                    palette = .placeholder
                    return
                }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let cgImage = cgImage(from: data) else { return }
                    let extracted = await extractor.extract(from: cgImage)
                    palette = extracted
                } catch {
                    // Stay as placeholder on download or decode failure.
                }
            }
    }

    private func cgImage(from data: Data) -> CGImage? {
#if canImport(UIKit)
        UIImage(data: data)?.cgImage
#elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
#else
        nil
#endif
    }
}
