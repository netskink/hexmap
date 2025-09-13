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
  A[AppDelegate.swift] --> B[@main AppDelegate : UIApplicationDelegate]
  B --> F1["application(_:didFinishLaunchingWith…launchOptions:) -> Bool"]
  B --> F2["applicationWillResignActive(_:)"]
  B --> F3["applicationDidEnterBackground(_:)"]
  B --> F4["applicationWillEnterForeground(_:)"]
  B --> F5["applicationDidBecomeActive(_:)"]
```



