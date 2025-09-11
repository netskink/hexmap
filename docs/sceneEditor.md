
Coordinate system & node graph
    •    Scene coordinates: default SpriteKit scene has origin at lower-left; keep it.
    •    Add a container:
    •    world (SKNode) — holds everything scrollable/zoomable.
    •    tileMap (SKTileMapNode, hex pointy)
    •    anchorPoint = (0, 0)
    •    position = (0, 0) → its lower-left corner sits at the world origin
    •    any other map content (units, overlays, debug layers) placed in world space
    •    Add a camera:
    •    camera (SKCameraNode), assigned to scene.camera
    •    Initially center it over the map:
camera.position = CGPoint(x: tileMap.frame.midX, y: tileMap.frame.midY)


In Scene Editor, you have a node heirarchy on left.  Use the menu to
open the library.  View->Show Library.  To add the world (SKNode),
type Node in the search bar and then drag Empty to the canvas.

In the node heirachy, select all three: Scene, world, tile map node and
set position and anchor point if they exist to 0,0.


