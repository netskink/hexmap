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
  File1[ "AppDelegate.swift" ]
  AppDel[ "AppDelegate : UIApplicationDelegate" ]
  File1 --> AppDel
  AppDel --> F1[ "application(_:didFinishLaunchingWithOptions:)" ]
  AppDel --> F2[ "applicationWillResignActive(_:)" ]
  AppDel --> F3[ "applicationDidEnterBackground(_:)" ]
  AppDel --> F4[ "applicationWillEnterForeground(_:)" ]
  AppDel --> F5[ "applicationDidBecomeActive(_:)" ]
```



