import SpriteKit

final class HexAssetScene: SKScene {

    private var didBuild = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        if !didBuild {
            didBuild = true
            buildFromAssets()
        }
    }

    private func buildFromAssets() {
        
        // The name here is not the name of the tileset as shown in left most navbar.
        // Instead this name corresponds to the spritekit tileset name in the spritekit navbar shown
        // in the spritekit editor for the selected tileset in the left most navbar.
        guard let tileSet = SKTileSet(named: "MyTileSet")
        else {
            let label = SKLabelNode(text: "Missing Tile Set: 'MyTitleSet' in Assets.xcassets")
            label.fontName = "Menlo"
            label.fontSize = 10
            label.fontColor = .red
            label.position = CGPoint(x: size.width/2, y: size.height/2)
            addChild(label)
            return
        }

        // He uses rows and columns?
        let cols = 3
        let rows = 8
        // This is a node that lays out a grid of tiles
        //
        // SKTileMapNode does the work of laying out predefined tiles in a grid of any size.
        // Typically, you configure 9-slice images (tile groups) in Xcode's SpriteKit scene
        // editor and paint the look of your tile map ahead of time versus configuring the
        //tile map in code.
        let map = SKTileMapNode(tileSet: tileSet,
                           columns: cols,
                           rows: rows,
                           tileSize: tileSet.defaultTileSize)
        // spritekit can do auto-tiling - rules that pick tiles based upon neighbors
        // When set false, i manually assign tiles using setTileGroup.
        map.enableAutomapping = false
        // the anchor of the map node is the center of the screen
        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        map.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(map)

        // Fetch groups by name (as you create them in Xcode)
        // This function returns all tilegroups with given input name
        func group(_ name: String) -> SKTileGroup? {
            tileSet.tileGroups.first { $0.name == name }
        }
        
        // To dump all the names do this:
        // output:
        // Tile group: dirtgroup
        // Tile group: grassgroup
        // Tile group: watergroup
        //
        // tileSet.tileGroups iterates all the groups in the tilegroup
        for g in tileSet.tileGroups {
            print("Tile group: \(g.name ?? "<unnamed>")")
        }

        // This code filters the available tilegroup into a subset.
        // If none are found, the fallback code below will use all available
        // tilegroups.
        
        // group("somename") returns an optional SKTileGroup? (because it might not
        // exist in the Tile Set.)  Doing it three times and assign to an array.
        //
        // .compactMap{$0} takes each element in the array.
        // $0 is the optional itself
        // compactMap unwraps non-nil values and throws away nils.
        // The result is [ SKTileGroup("dirtgroup") ] if dirtgroup is the only valid specified
        // group name.
        let palette = [group("dirtgroup"),
                      group("grassgroup"),
                      group("watergroup")].compactMap {
            $0 }

        // this dumps the palette variable
        print("Palette contains \(palette.count) groups:")
        for g in palette {
            print(" - \(g.name ?? "<unnamed>")")
        }
        
        // fallback is either the subset (identified by palette) or complete available set of tileGroups.
        let fallback = palette.isEmpty ? tileSet.tileGroups : palette

        
        for r in 0..<rows {
            for c in 0..<cols {
                // every 3 columns or 2 rows, switch tile groups
                // the pick ranges from 1 to 1 or 0 to count of items in fallback.
                // This is a mod operator.
                // pick looks like this: 000111222000111222
                let pick = (c / 3 + r / 2) % max(1, fallback.count)
                print("\(pick)")
                map.setTileGroup(fallback[pick], forColumn: c, row: r)
            }
        }
    }
}
