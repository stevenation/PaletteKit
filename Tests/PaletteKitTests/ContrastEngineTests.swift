//
//  ContrastEngineTests.swift
//  PaletteKitTests
//
//  Created by Thabiso G. Setefane on 25/05/2026.
//  Copyright © 2026 Thabiso G. Setefane. All rights reserved.
//

import XCTest
@testable import PaletteKit

final class ContrastEngineTests: XCTestCase {

    // MARK: - Luminance

    func testBlackLuminanceIsZero() {
        XCTAssertEqual(ContrastEngine.luminance(0, 0, 0), 0.0, accuracy: 0.001)
    }

    func testWhiteLuminanceIsOne() {
        XCTAssertEqual(ContrastEngine.luminance(1, 1, 1), 1.0, accuracy: 0.001)
    }

    // MARK: - Contrast Ratio

    func testWhiteOnBlackIs21() {
        let white = ContrastEngine.luminance(1, 1, 1)
        let black = ContrastEngine.luminance(0, 0, 0)
        XCTAssertEqual(ContrastEngine.contrastRatio(luminance: white, luminance: black), 21.0, accuracy: 0.01)
    }

    func testBlackOnWhiteIs21() {
        let white = ContrastEngine.luminance(1, 1, 1)
        let black = ContrastEngine.luminance(0, 0, 0)
        XCTAssertEqual(ContrastEngine.contrastRatio(luminance: black, luminance: white), 21.0, accuracy: 0.01)
    }

    func testContrastRatioIsSymmetric() {
        let l1 = ContrastEngine.luminance(0.3, 0.5, 0.8)
        let l2 = ContrastEngine.luminance(0.1, 0.1, 0.1)
        XCTAssertEqual(
            ContrastEngine.contrastRatio(luminance: l1, luminance: l2),
            ContrastEngine.contrastRatio(luminance: l2, luminance: l1),
            accuracy: 0.001
        )
    }

    func testContrastRatioAlwaysAtLeastOne() {
        let l = ContrastEngine.luminance(0.5, 0.5, 0.5)
        XCTAssertGreaterThanOrEqual(ContrastEngine.contrastRatio(luminance: l, luminance: l), 1.0)
    }

    // MARK: - Foreground

    func testForegroundOnWhiteIsBlack() {
        let fg = ContrastEngine.foreground(against: RGB(r: 1, g: 1, b: 1))
        XCTAssertEqual(fg.r, 0)
        XCTAssertEqual(fg.g, 0)
        XCTAssertEqual(fg.b, 0)
    }

    func testForegroundOnBlackIsWhite() {
        let fg = ContrastEngine.foreground(against: RGB(r: 0, g: 0, b: 0))
        XCTAssertEqual(fg.r, 1)
        XCTAssertEqual(fg.g, 1)
        XCTAssertEqual(fg.b, 1)
    }

    func testForegroundReturnsOnlyBlackOrWhite() {
        let midGray = RGB(r: 0.5, g: 0.5, b: 0.5)
        let fg = ContrastEngine.foreground(against: midGray)
        let isBlack = fg.r == 0 && fg.g == 0 && fg.b == 0
        let isWhite = fg.r == 1 && fg.g == 1 && fg.b == 1
        XCTAssertTrue(isBlack || isWhite)
    }

    // MARK: - EnforceContrast

    func testEnforceContrastAchievesMinimumRatio() {
        let lowContrast = RGB(r: 0.55, g: 0.55, b: 0.55)
        let bg = RGB(r: 0.5, g: 0.5, b: 0.5)
        let adjusted = ContrastEngine.enforceContrast(lowContrast, against: bg, minimumRatio: 3.0)
        let bgLum  = ContrastEngine.luminance(bg.r, bg.g, bg.b)
        let adjLum = ContrastEngine.luminance(adjusted.r, adjusted.g, adjusted.b)
        let ratio  = ContrastEngine.contrastRatio(luminance: adjLum, luminance: bgLum)
        XCTAssertGreaterThanOrEqual(ratio, 3.0)
    }

    func testEnforceContrastPassthroughWhenAlreadyOk() {
        // White on black already has 21:1 — should be returned unchanged (or near it).
        let white = RGB(r: 1, g: 1, b: 1)
        let black = RGB(r: 0, g: 0, b: 0)
        let result = ContrastEngine.enforceContrast(white, against: black, minimumRatio: 4.5)
        let bgLum  = ContrastEngine.luminance(black.r, black.g, black.b)
        let resLum = ContrastEngine.luminance(result.r, result.g, result.b)
        XCTAssertGreaterThanOrEqual(ContrastEngine.contrastRatio(luminance: resLum, luminance: bgLum), 4.5)
    }

    // MARK: - HSL Round-trip

    func testHslRoundTrip() {
        let r = 0.8, g = 0.3, b = 0.1
        let (h, s, l) = ContrastEngine.rgbToHsl(r, g, b)
        let (rOut, gOut, bOut) = ContrastEngine.hslToRgb(h, s, l)
        XCTAssertEqual(rOut, r, accuracy: 0.001)
        XCTAssertEqual(gOut, g, accuracy: 0.001)
        XCTAssertEqual(bOut, b, accuracy: 0.001)
    }

    func testGrayHasSaturationZero() {
        let (_, s, _) = ContrastEngine.rgbToHsl(0.5, 0.5, 0.5)
        XCTAssertEqual(s, 0, accuracy: 0.001)
    }
}
