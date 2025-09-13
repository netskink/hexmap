#  Notes

# AppDelegate.swift

```
UIKit app delegate with @main and these lifecycle methods:
    •    application(_:didFinishLaunchingWith… launchOptions:) -> Bool
    •    applicationWillResignActive(_:)
    •    applicationDidEnterBackground(_:)
    •    applicationWillEnterForeground(_:)
    •    applicationDidBecomeActive(_:)
```    

## call map

```mermaid
graph TD
  File1["AppDelegate.swift"]
  AppDel["AppDelegate : UIApplicationDelegate"]
  File1 --> AppDel
  AppDel --> F1["application(_:didFinishLaunchingWithOptions:) -> Bool"]
  AppDel --> F2["applicationWillResignActive(_:)"]
  AppDel --> F3["applicationDidEnterBackground(_:)"]
  AppDel --> F4["applicationWillEnterForeground(_:)"]
  AppDel --> F5["applicationDidBecomeActive(_:)"]
```


# GameViewController.swift

Mostly unchanged from xcode template.

## call map

```mermaid
graph TD
  File1["GameViewController.swift"]
  GVC["GameViewController : UIViewController"]
  File1 --> GVC
  GVC --> M1["viewDidLoad()"]
  GVC --> M2["handlePinch(_: UIPinchGestureRecognizer)"]
  GVC --> M3["handlePan(_: UIPanGestureRecognizer)"]
  GVC --> M4["supportedInterfaceOrientations -> UIInterfaceOrientationMask"]
  GVC --> M5["prefersStatusBarHidden -> Bool"]
  ```
  
  # SKTileMapNode_ext.swift
  
  Updates for SKTileMapNode so that it can determine nearest neighbors
  and BFS search.
  
  ## call map

```mermaid
graph TD
  File1["SKTileMapNode_ext.swift"]
  Ext["extension SKTileMapNode"]
  File1 --> Ext
  Ext --> F1["center(_:_: ) -> CGPoint"]
  Ext --> F2["proximityNeighbors(col:row:) -> [(col,row)]"]
  Ext --> F3["inBounds(col:row:) -> Bool"]
  Ext --> F4["isWalkable(col:row:) -> Bool"]
  Ext --> F5["bfsPath(from:to:) -> [(col,row)]?"]
  Ext --> F6["nextStepToward(start:goal:) -> (col,row)?"]
  ```
  
  # GameScene.swift
  
  ## call map

```mermaid
graph TD
  File1["GameScene.swift"]
  GS["GameScene : SKScene"]
  File1 --> GS
  GS --> E1["enum Turn { player, computer }"]

  %% Lifecycle
  GS --> M1["didMove(to:)"]

  %% Unit / helpers
  GS --> M2["addUnit(named:atRow:column:) -> SKNode"]
  GS --> M3["tileIndex(of:) -> (col,row)"]
  GS --> M4["worldPointForTile(col:row:) -> CGPoint"]

  %% Input & highlights
  GS --> M5["touchesEnded(_:with:)"]
  GS --> M6["clearMoveHighlights()"]
  GS --> M7["showMoveHighlights(from:)"]

  %% Turn flow
  GS --> M8["enablePlayerInput(_:)"]
  GS --> M9["endTurn()"]
  GS --> M10["runComputerTurn()"]

  %% Movement
  GS --> M11["moveUnit(_:toCol:row:completion:)"]
  ```
  
