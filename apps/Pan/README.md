
1. AppDelegate.swift
    •    Handles app lifecycle events (launching, entering background, etc.).
    •    You typically don’t need to modify this much for simple games.

2. GameViewController.swift
    •    Sets up and presents the initial SKScene (GameScene.swift) to the screen.
    •    Handles the connection between UIKit and SpriteKit.

3. GameScene.swift
    •    This is the main SpriteKit scene class (SKScene) where you implement your game logic.
    •    It probably contains a label node, like:
4. GameScene.sks
    •    A visual scene file created by Xcode’s SpriteKit editor.
    •    Lets you lay out nodes without writing code.
    •    Can be loaded using: SKScene(fileNamed: "GameScene")    

The GameScene is loaded in GameViewController.swift like this:

```
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            if let scene = SKScene(fileNamed: "GameScene") {
                // Set the scale mode to scale to fit the window
                scene.scaleMode = .aspectFill
                
                // Present the scene
                view.presentScene(scene)
            }
```
5. Assets.xcassets
    •    Contains image and color assets for your game.
    •    You can add sprite images here for use in your scene.

6. Base.lproj
    •    Localization directory that holds interface files.
    •    Contains:

a. LaunchScreen.storyboard
    •    Defines the launch screen the user sees before the app is ready.
    •    Often just a static image or logo.

b. Main.storyboard
    •    Main UI file for UIKit apps.
    •    The SpriteKit template uses this to embed the GameViewController.
