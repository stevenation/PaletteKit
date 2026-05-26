//
//  PaletteExtractor.swift
//  PaletteKit
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

import CoreGraphics

actor PaletteExtractor {

    func extract(from cgImage: CGImage) async -> ImagePalette {
        guard let buffer = downsample(cgImage) else { return .placeholder }
        let pixels = collectOpaquePixels(from: buffer)
        guard !pixels.isEmpty else { return .placeholder }
        let buckets = medianCut(pixels, iterations: 5)
        return assignRoles(from: buckets)
    }

    // MARK: - Types

    private struct Pixel {
        let r: UInt8, g: UInt8, b: UInt8
    }

    private struct Bucket {
        var pixels: [Pixel]

        var representative: RGB {
            guard !pixels.isEmpty else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
            let n = Double(pixels.count)
            let r = pixels.reduce(0) { $0 + Int($1.r) }
            let g = pixels.reduce(0) { $0 + Int($1.g) }
            let b = pixels.reduce(0) { $0 + Int($1.b) }
            return RGB(r: Double(r) / (n * 255), g: Double(g) / (n * 255), b: Double(b) / (n * 255))
        }

        var colorRange: Int {
            guard !pixels.isEmpty else { return 0 }
            let (rLo, rHi, gLo, gHi, bLo, bHi) = pixels.reduce(
                (UInt8(255), UInt8(0), UInt8(255), UInt8(0), UInt8(255), UInt8(0))
            ) { acc, p in
                (min(acc.0, p.r), max(acc.1, p.r),
                 min(acc.2, p.g), max(acc.3, p.g),
                 min(acc.4, p.b), max(acc.5, p.b))
            }
            return max(Int(rHi) - Int(rLo), max(Int(gHi) - Int(gLo), Int(bHi) - Int(bLo)))
        }
    }

    // MARK: - Downsampling

    // Renders cgImage into a 64×64 BGRA8888 bitmap and returns the raw bytes.
    private func downsample(_ image: CGImage) -> [UInt8]? {
        let side = 64
        let bytesPerRow = side * 4

        guard let ctx = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        guard let data = ctx.data else { return nil }
        let count = bytesPerRow * side
        return Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: count
        ))
    }

    // MARK: - Pixel Collection

    // BGRA layout: byte[0]=B, byte[1]=G, byte[2]=R, byte[3]=A
    private func collectOpaquePixels(from buffer: [UInt8]) -> [Pixel] {
        var pixels: [Pixel] = []
        pixels.reserveCapacity(buffer.count / 4)
        var i = 0
        while i + 3 < buffer.count {
            if buffer[i + 3] >= 10 {
                pixels.append(Pixel(r: buffer[i + 2], g: buffer[i + 1], b: buffer[i]))
            }
            i += 4
        }
        return pixels
    }

    // MARK: - Median Cut

    // 5 iterations → up to 32 buckets
    private func medianCut(_ pixels: [Pixel], iterations: Int) -> [Bucket] {
        var buckets = [Bucket(pixels: pixels)]
        for _ in 0..<iterations {
            guard let idx = buckets.indices.max(by: { buckets[$0].colorRange < buckets[$1].colorRange }),
                  buckets[idx].colorRange > 0 else { break }
            let bucket = buckets.remove(at: idx)
            let (a, b) = split(bucket)
            buckets.append(contentsOf: [a, b])
        }
        return buckets
    }

    private func split(_ bucket: Bucket) -> (Bucket, Bucket) {
        let px = bucket.pixels
        guard px.count > 1 else { return (bucket, Bucket(pixels: [])) }

        let (rLo, rHi, gLo, gHi, bLo, bHi) = px.reduce(
            (UInt8(255), UInt8(0), UInt8(255), UInt8(0), UInt8(255), UInt8(0))
        ) { acc, p in
            (min(acc.0, p.r), max(acc.1, p.r),
             min(acc.2, p.g), max(acc.3, p.g),
             min(acc.4, p.b), max(acc.5, p.b))
        }
        let rRange = Int(rHi) - Int(rLo)
        let gRange = Int(gHi) - Int(gLo)
        let bRange = Int(bHi) - Int(bLo)

        let sorted: [Pixel]
        if rRange >= gRange && rRange >= bRange {
            sorted = px.sorted { $0.r < $1.r }
        } else if gRange >= bRange {
            sorted = px.sorted { $0.g < $1.g }
        } else {
            sorted = px.sorted { $0.b < $1.b }
        }

        let mid = sorted.count / 2
        return (Bucket(pixels: Array(sorted[..<mid])), Bucket(pixels: Array(sorted[mid...])))
    }

    // MARK: - Role Assignment

    private func assignRoles(from buckets: [Bucket]) -> ImagePalette {
        guard !buckets.isEmpty else { return .placeholder }

        let reps = buckets.map { (rgb: $0.representative, count: $0.pixels.count) }

        guard let dominant = reps.max(by: { $0.count < $1.count })?.rgb else {
            return .placeholder
        }

        let vibrantSource = reps.filter { let h = hsl($0.rgb); return h.l >= 0.25 && h.l <= 0.85 }
        guard let vibrant = (vibrantSource.isEmpty ? reps : vibrantSource)
            .max(by: { hsl($0.rgb).s < hsl($1.rgb).s })?.rgb else { return .placeholder }

        let mutedSource = reps.filter { let h = hsl($0.rgb); return h.l >= 0.2 && h.l <= 0.8 }
        guard let muted = (mutedSource.isEmpty ? reps : mutedSource)
            .min(by: { hsl($0.rgb).s < hsl($1.rgb).s })?.rgb else { return .placeholder }

        guard let dark  = reps.min(by: { lum($0.rgb) < lum($1.rgb) })?.rgb,
              let light = reps.max(by: { lum($0.rgb) < lum($1.rgb) })?.rgb else {
            return .placeholder
        }

        let fgRGB  = ContrastEngine.foreground(against: dominant)
        let sfgRGB = ContrastEngine.secondaryForeground(against: dominant)
        let accentRGB = ContrastEngine.enforceContrast(vibrant, against: dominant, minimumRatio: 3.0)

        return ImagePalette(
            dominant: dominant,
            vibrant: vibrant,
            muted: muted,
            dark: dark,
            light: light,
            foreground: fgRGB.color,
            secondaryForeground: sfgRGB.color,
            accent: accentRGB.color
        )
    }

    private func hsl(_ rgb: RGB) -> (h: Double, s: Double, l: Double) {
        ContrastEngine.rgbToHsl(rgb.r, rgb.g, rgb.b)
    }

    private func lum(_ rgb: RGB) -> Double {
        ContrastEngine.luminance(rgb.r, rgb.g, rgb.b)
    }
}
