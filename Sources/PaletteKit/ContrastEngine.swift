//
//  ContrastEngine.swift
//  PaletteKit
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

// WCAG 2.1 contrast utilities. All functions are pure — no state, no side effects.
enum ContrastEngine {

    // MARK: - WCAG Luminance & Ratio

    static func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func linearize(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    static func contrastRatio(luminance l1: Double, luminance l2: Double) -> Double {
        let lighter = max(l1, l2)
        let darker  = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Foreground Selection

    /// Returns pure black or pure white — whichever has higher contrast against bg.
    static func foreground(against bg: RGB) -> RGB {
        let bgLum = luminance(bg.r, bg.g, bg.b)
        let whiteContrast = contrastRatio(luminance: 1.0, luminance: bgLum)
        let blackContrast = contrastRatio(luminance: 0.0, luminance: bgLum)
        return whiteContrast > blackContrast ? RGB(r: 1, g: 1, b: 1) : RGB(r: 0, g: 0, b: 0)
    }

    /// Simulates 60% opacity of the primary foreground blended over bg.
    static func secondaryForeground(against bg: RGB) -> RGB {
        let fg = foreground(against: bg)
        return RGB(
            r: fg.r * 0.6 + bg.r * 0.4,
            g: fg.g * 0.6 + bg.g * 0.4,
            b: fg.b * 0.6 + bg.b * 0.4
        )
    }

    // MARK: - Contrast Enforcement

    /// Shifts `color` lightness until contrast against `bg` reaches `minimumRatio`.
    /// Falls back to pure foreground after 20 iterations.
    static func enforceContrast(_ color: RGB, against bg: RGB, minimumRatio: Double) -> RGB {
        let bgLum = luminance(bg.r, bg.g, bg.b)
        var (h, s, l) = rgbToHsl(color.r, color.g, color.b)
        let direction: Double = bgLum > 0.5 ? -1.0 : 1.0

        for _ in 0..<20 {
            let (r, g, b) = hslToRgb(h, s, l)
            if contrastRatio(luminance: luminance(r, g, b), luminance: bgLum) >= minimumRatio {
                return RGB(r: r, g: g, b: b)
            }
            l = max(0, min(1, l + direction * 0.04))
        }

        return foreground(against: bg)
    }

    // MARK: - HSL Helpers (internal so PaletteExtractor can reuse)

    static func rgbToHsl(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let delta = maxC - minC
        let l = (maxC + minC) / 2
        guard delta > 0 else { return (0, 0, l) }
        let s = delta / (1 - abs(2 * l - 1))
        var h: Double
        if maxC == r {
            h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h /= 6
        if h < 0 { h += 1 }
        return (h, s, l)
    }

    static func hslToRgb(_ h: Double, _ s: Double, _ l: Double) -> (r: Double, g: Double, b: Double) {
        guard s > 0 else { return (l, l, l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        func hueChannel(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }

        return (hueChannel(h + 1 / 3), hueChannel(h), hueChannel(h - 1 / 3))
    }
}
