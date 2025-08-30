
# Scene Editor Tile Map Starter (SwiftUI + SpriteKit)

This starter loads a map you create visually in Xcode's Scene Editor (`Level1.sks`), including a Tile Map Node that uses your Asset Catalog Tile Set.

## Files
- `SceneEditorApp.swift` — SwiftUI @main entry.
- `ContentView.swift` — Hosts the SpriteKit scene in `SpriteView`. Loads `Level1.sks`.
- `LevelScene.swift` — Your scene class. Prints tile group names and shows them on screen.
- You create: `Level1.sks` in Xcode (see below).

## 1) Create the Tile Set (Assets.xcassets)
1. Open Assets.xcassets.
2. Right‑click → New Tile Set → name it HexTiles (or anything).
3. Select the Tile Set:
   - Tile Set Type: Hexagonal Pointy (or Hexagonal Flat / Grid)
   - Default Tile Size: e.g. 48×48 (match your art in points)
4. Under "Tile Groups", add groups like grass, water, dirt.
5. For each group, add a Tile Definition and assign a texture (import PNGs as Image Sets first).

## 2) Create the Scene in Scene Editor
1. File → New → File… → SpriteKit Scene, name it Level1.sks.
2. Open Level1.sks:
   - Attributes Inspector → Custom Class = LevelScene.
3. Add a Tile Map Node (⌘⇧L → Tile Map Node) into the scene.
   - Name = Map (so code can find it).
   - Tile Set = your set (e.g., HexTiles).
   - Columns, Rows, Tile Size configured to match the set.
   - Position as desired.

Paint tiles using the palette bar at the bottom of the editor.

## 3) Run it
Build & run. ContentView loads Level1.sks as LevelScene. On launch, LevelScene finds the Tile Map named "Map", prints the Tile Set group names, and shows them at the top of the screen.

## Troubleshooting
- Can't find Level1.sks: ensure it's in the target and spelled exactly.
- Cast to LevelScene fails: set Custom Class = LevelScene in the .sks.
- No tile palette: assign a Tile Set to the Tile Map Node in the editor.
- Tiles stretched: Tile Map's Tile Size must match the Tile Set's Default Tile Size and your art.
- SwiftUI storyboard error: leave Main Interface blank in target settings.
