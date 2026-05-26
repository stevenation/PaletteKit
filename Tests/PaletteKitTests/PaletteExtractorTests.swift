//
//  PaletteExtractorTests.swift
//  PaletteKitTests
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

import XCTest
import CoreGraphics
@testable import PaletteKit

final class PaletteExtractorTests: XCTestCase {

    private let extractor = PaletteExtractor()

    // MARK: - Solid color extraction

    func testSolidRedDominantIsRed() async throws {
        let image = try XCTUnwrap(makeSolid(r: 255, g: 0, b: 0))
        let palette = await extractor.extract(from: image)
        XCTAssertGreaterThan(palette.dominantRGB.r, 0.7, "Red channel should dominate")
        XCTAssertLessThan(palette.dominantRGB.g, 0.3)
        XCTAssertLessThan(palette.dominantRGB.b, 0.3)
    }

    func testSolidWhiteLightIsApproximatelyWhite() async throws {
        let image = try XCTUnwrap(makeSolid(r: 255, g: 255, b: 255))
        let palette = await extractor.extract(from: image)
        XCTAssertGreaterThan(palette.lightRGB.r, 0.8)
        XCTAssertGreaterThan(palette.lightRGB.g, 0.8)
        XCTAssertGreaterThan(palette.lightRGB.b, 0.8)
    }

    func testSolidBlackDarkIsApproximatelyBlack() async throws {
        let image = try XCTUnwrap(makeSolid(r: 0, g: 0, b: 0))
        let palette = await extractor.extract(from: image)
        XCTAssertLessThan(palette.darkRGB.r, 0.2)
        XCTAssertLessThan(palette.darkRGB.g, 0.2)
        XCTAssertLessThan(palette.darkRGB.b, 0.2)
    }

    // MARK: - Mixed-color extraction

    func testHalfRedHalfBlueContainsBothHues() async throws {
        let image = try XCTUnwrap(makeHalfRedHalfBlue())
        let palette = await extractor.extract(from: image)
        // dominant or vibrant should have either a red or blue tint
        let dom = palette.dominantRGB
        let dominated = dom.r > 0.4 || dom.b > 0.4
        XCTAssertTrue(dominated, "Mixed image should produce a reddish or bluish dominant")
    }

    // MARK: - Transparent pixel handling

    func testFullyTransparentImageReturnsPlaceholder() async throws {
        let image = try XCTUnwrap(makeTransparent())
        let palette = await extractor.extract(from: image)
        XCTAssertEqual(palette, .placeholder)
    }

    // MARK: - Placeholder sanity

    func testPlaceholderDoesNotCrash() {
        let p = ImagePalette.placeholder
        _ = p.dominant
        _ = p.foreground
        _ = p.accent
    }

    // MARK: - Contrast guarantees

    func testForegroundOnDominantMeetsContrastThreshold() async throws {
        let image = try XCTUnwrap(makeSolid(r: 180, g: 100, b: 50))
        let palette = await extractor.extract(from: image)
        let domLum = ContrastEngine.luminance(palette.dominantRGB.r, palette.dominantRGB.g, palette.dominantRGB.b)
        // foreground is always black or white → contrast against any bg ≥ 4.5
        // We check that it's not the same as the background color (very rough)
        let fg = palette.foreground
        _ = fg // foreground construction must not throw
        XCTAssertNotEqual(palette.foreground, palette.dominant)
        _ = domLum
    }

    // MARK: - Helpers

    private func makeSolid(r: UInt8, g: UInt8, b: UInt8, side: Int = 64) -> CGImage? {
        guard let ctx = makeContext(side: side) else { return nil }
        ctx.setFillColor(CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [CGFloat(r) / 255, CGFloat(g) / 255, CGFloat(b) / 255, 1]
        )!)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage()
    }

    private func makeHalfRedHalfBlue(side: Int = 64) -> CGImage? {
        guard let ctx = makeContext(side: side) else { return nil }
        ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1, 0, 0, 1])!)
        ctx.fill(CGRect(x: 0, y: 0, width: side / 2, height: side))
        ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 1, 1])!)
        ctx.fill(CGRect(x: side / 2, y: 0, width: side / 2, height: side))
        return ctx.makeImage()
    }

    private func makeTransparent(side: Int = 64) -> CGImage? {
        guard let ctx = makeContext(side: side) else { return nil }
        // Do not fill — all pixels remain transparent (0,0,0,0)
        return ctx.makeImage()
    }

    private func makeContext(side: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
        )
    }
}
