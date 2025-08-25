
# SpriteKit Hex Map (SwiftUI)

A minimal, working SpriteKit hex grid demo for iOS.

## Files

- `HexMapApp.swift` — SwiftUI entry point.
- `ContentView.swift` — Hosts the SpriteKit scene using `SpriteView`.
- `HexScene.swift` — Draws a pointy-top axial hex grid, handles tap selection, and includes pixel<->axial conversions with cube rounding.

## How to use in Xcode

1. **Create a new project**: iOS > App (SwiftUI, Swift).
2. Name it `SpriteKitHexMap` (or anything), Interface **SwiftUI**, Language **Swift**.
3. Check “Include Tests” off if you want to keep it minimal.
4. In the new project, delete the auto-generated `ContentView.swift` and `YourAppNameApp.swift`.
5. Drag the three Swift files from this folder into your Xcode project (copy if needed).
6. Build & Run on iPhone simulator or device.

### Tuning

- Toggle **flat-top** vs **pointy-top** in `HexScene` by changing `pointyTop`.
- Change `hexSize` or `mapRadius` to resize the grid or its footprint.
- To make a rectangular map, replace the hex-disc loops with row/column loops and place with `axialToPixel`.

## Requirements

- Xcode 15+
- iOS 15+
- Swift 5.9+
- SpriteKit (included in iOS SDK)
