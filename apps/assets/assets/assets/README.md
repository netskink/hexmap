# Hex Tile Set via Xcode Asset Catalog (No Programmatic Art)

This template shows how to use **Xcode’s tile tools** (Asset Catalog) to build a hexagonal tileset,
and load it with `SKTileSet(named:)` from SpriteKit. No code draws tiles — you use Xcode’s UI.


Tile Sets are created via the file new from template menu.  
They are not created within the asset catalog.

Once you create the TileSet, you drag the same images used there from the explorer to a spritekit atlas in the assets.  Use the right hand side info for each item in the tileset atlas to refer to the spritekit atlas.





## What’s included
- `HexTilesAssetCatalogApp.swift`, `ContentView.swift`, `HexAssetScene.swift`
- `Art/grass.png`, `Art/water.png`, `Art/dirt.png` — sample images you can import as tiles

## Step-by-step: create the tiles **in Xcode**

1. **Create a new iOS App (SwiftUI)**, iOS 15+.
2. Replace the generated Swift files with the three from this folder.
3. In the Project navigator, open **Assets.xcassets**.
4. Click the **+** at the bottom-left → **New Tile Set**. Name it **HexTiles**.
5. Select the new **HexTiles** tile set. In the Attributes inspector (right panel):
   - **Tile Set Type**: **Hexagonal Pointy** (for pointy-top hexes) or **Hexagonal Flat** if you prefer.
   - **Default Tile Size**: e.g. **48 x 48** (or 32 x 32). This should match your PNG dimensions in points.
6. With **HexTiles** selected, click the small **+** under “Tile Groups” to add three groups.
   - Rename each group to: **grass**, **water**, **dirt** (the code looks these up by name).
7. Click a group (e.g., *grass*). In the center editor, you’ll see a **Tile Definitions** grid.
   - Click the **+** button under Tile Definitions to add one definition.
   - In the Attributes inspector, set **Texture** to an image from your asset catalog.
     - Drag **Art/grass.png** from Finder into **Assets.xcassets** (as an Image Set), then pick it here.
   - Repeat for **water** and **dirt** using the provided PNGs.
   - (Optional) You can add multiple definitions per group for randomization/variations.
8. Build and run. The scene calls:
   ```swift
   let tileSet = SKTileSet(named: "HexTiles")
   let map = SKTileMapNode(tileSet: tileSet, columns: 18, rows: 8, tileSize: tileSet.defaultTileSize)
   ```
   and fills the map with your **grass/water/dirt** groups.

### Tips
- **Sizes**: If your PNGs are 48×48, set the Tile Set’s **Default Tile Size** to **48×48** so the map looks correct.
- **Hex orientation**: Switch between **Hexagonal Pointy** / **Hexagonal Flat** in the Tile Set and re-run.
- **Group names**: If you change names, update the code that looks them up.
- **Automapping**: Xcode can define adjacency rules for autotiling. For a simple demo, we explicitly place groups.

## Using different pixel scales
You can create multiple tile sets (e.g., `HexTiles48`, `HexTiles32`) in the same asset catalog with different Default Tile Sizes, then switch which one you load in `HexAssetScene`.

## Troubleshooting
- **“Missing Tile Set” label** → Make sure the tile set is named exactly **HexTiles** in Assets.xcassets.
- **Stretched or tiny tiles** → Mismatch between PNG size and Default Tile Size. Keep them the same (in points).
- **Storyboard error** → For SwiftUI apps, ensure target **Main Interface** field is empty (no storyboard).
