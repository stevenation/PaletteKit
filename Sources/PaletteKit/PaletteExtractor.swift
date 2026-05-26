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
            let rRange = Int(pixels.max { $0.r < $1.r }!.r) - Int(pixels.min { $0.r < $1.r }!.r)
            let gRange = Int(pixels.max { $0.g < $1.g }!.g) - Int(pixels.min { $0.g < $1.g }!.g)
            let bRange = Int(pixels.max { $0.b < $1.b }!.b) - Int(pixels.min { $0.b < $1.b }!.b)
            return max(rRange, max(gRange, bRange))
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

        let rRange = Int(px.max { $0.r < $1.r }!.r) - Int(px.min { $0.r < $1.r }!.r)
        let gRange = Int(px.max { $0.g < $1.g }!.g) - Int(px.min { $0.g < $1.g }!.g)
        let bRange = Int(px.max { $0.b < $1.b }!.b) - Int(px.min { $0.b < $1.b }!.b)

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

        let dominant = reps.max { $0.count < $1.count }!.rgb

        let vibrantCandidates = reps.filter {
            let hsl = hsl($0.rgb); return hsl.l >= 0.25 && hsl.l <= 0.85
        }
        let vibrant = (vibrantCandidates.isEmpty ? reps : vibrantCandidates)
            .max { hsl($0.rgb).s < hsl($1.rgb).s }!.rgb

        let mutedCandidates = reps.filter {
            let hsl = hsl($0.rgb); return hsl.l >= 0.2 && hsl.l <= 0.8
        }
        let muted = (mutedCandidates.isEmpty ? reps : mutedCandidates)
            .min { hsl($0.rgb).s < hsl($1.rgb).s }!.rgb

        let dark  = reps.min { lum($0.rgb) < lum($1.rgb) }!.rgb
        let light = reps.max { lum($0.rgb) < lum($1.rgb) }!.rgb

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
