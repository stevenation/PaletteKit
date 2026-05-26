<p align="center">
  <img src="https://img.shields.io/badge/MacOS-14+-blue.svg" alt="MacOS">
  <img src="https://img.shields.io/badge/iOS-17+-green.svg" alt="iOS">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift">
</p>

# PaletteKit

A Swift Package Manager library that extracts a semantic color palette from any image and propagates it through a SwiftUI view hierarchy as an environment value — zero prop drilling, guaranteed WCAG AA contrast on all color pairs.

---

## Installation

Add the package in Xcode via **File › Add Package Dependencies** and enter the repository URL, or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stevenation/PaletteKit", from: "1.0.0")
],
targets: [
    .target(name: "YourTarget", dependencies: ["PalleteKit"])
]
```

Requires **iOS 17+** or **macOS 14+**.

---

## 🌄 Example

<p align="center">
    <img src="https://github.com/stevenation/PaletteKit/blob/main/Assets/example.gif" style="display: block; margin: auto;" height="400"/>
</p>

## Quick start

```swift
// Attach once at the image level
AsyncImage(url: track.artworkURL) { image in
    image.resizable().scaledToFill()
} placeholder: {
    Color.gray
}
.extractPalette(from: track.artworkURL)

// Consume anywhere in the subtree
struct NowPlayingCard: View {
    @Environment(\.palette) var palette

    var body: some View {
        VStack {
            Text(track.name).foregroundStyle(palette.foreground)
            Text(track.artist).foregroundStyle(palette.secondaryForeground)
            ProgressView(value: progress).tint(palette.accent)
        }
        .background(palette.dominant)
    }
}
```

---

## Full API reference

### `ImagePalette`

| Property | Description |
|---|---|
| `dominant` | Most visually prominent color (largest pixel cluster) |
| `vibrant` | Highest-saturation color with mid-range lightness |
| `muted` | Lowest-saturation color with mid-range lightness |
| `dark` | Darkest sampled color by WCAG luminance |
| `light` | Lightest sampled color by WCAG luminance |
| `foreground` | Pure black or white — guaranteed contrast against `dominant` |
| `secondaryForeground` | Same direction as `foreground` but 60%-opacity-equivalent |
| `accent` | `vibrant` adjusted until it reaches ≥ 3.0:1 contrast against `dominant` |
| `placeholder` | Neutral gray fallback shown before extraction completes |

### Modifiers

```swift
// UIImage (iOS) / NSImage (macOS) — re-extracts only when the image instance changes
view.extractPalette(from image: UIImage?) -> some View
view.extractPalette(from image: NSImage?) -> some View

// URL — downloads then extracts; stays as .placeholder on any error
view.extractPalette(from url: URL?) -> some View
```

### Environment key

```swift
@Environment(\.palette) var palette: ImagePalette
```

---

## How contrast is enforced

`foreground` and `secondaryForeground` are derived by computing the WCAG 2.1 relative luminance of the dominant color and selecting pure black or white, whichever produces the higher contrast ratio (always ≥ 4.5:1 against the dominant background). The `accent` color starts as `vibrant` and is iteratively shifted in HSL lightness space — 0.04 per step, up to 20 steps — until the contrast ratio against `dominant` reaches at least 3.0:1 (WCAG AA Large). If 20 iterations are insufficient, `accent` falls back to the same pure black or white used for `foreground`.

---

## Performance notes

- **64×64 downsample:** The input image is always scaled to 64×64 pixels via `CGContext` before any pixel is read. This caps extraction cost regardless of source image size.
- **Background actor:** `PaletteExtractor` is a Swift `actor`, so all CPU work (pixel traversal, median cut, contrast math) runs off the main thread. SwiftUI re-renders happen automatically when the `@State` palette is written back on the main actor.
- **Task deduplication:** The `.task(id:)` modifier re-triggers extraction only when the image instance (or URL) actually changes. Rapid view updates do not re-run extraction.

---

## Known limitations

- **Animated GIFs / APNG:** Only the first frame is used; `CGImage` does not decode animation.
- **HDR images:** CoreGraphics tone-maps HDR content into the sRGB color space during the 64×64 render. Extracted colors reflect the tone-mapped values, not the original HDR primaries.
- **Very small or sparse images:** Images with fewer than one opaque pixel after downsampling return `.placeholder`.
