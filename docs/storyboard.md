#  Storyboard Notes




|Feature|Launch Screen Storyboard|Main Storyboard|
|-------|------------------------|---------------|
|Purpose|Shown immediately when the user taps the app icon; before your app is fully loaded. It gives something for the user to see while startup is in progress.| The main UI of your app — the actual starting point after the launch screen. This is where your interactive views, navigation, etc., live.|
|Static vs Dynamic|Must be static (no code execution, no custom view controllers with logic). The interface can include basic UIKit views, constraints, and size classes so it adapts to device sizes. |Fully interactive and dynamic; supports view controllers, code, business logic, etc.|
|Configuration|Set in Xcode under the project settings → “Launch Screen File” or via the UILaunchStoryboardName key in Info.plist. |Configured under “Main Interface” (or via your scene delegate depending on your app life-cycle).|
|Timing|Displayed before the app enters its main run loop, before your code (especially heavy initialization) completes. It must be very lightweight.| Displayed after launch screen, when your app is ready to take over.|
|Restrictions|No custom code, no animations (beyond what layout constraints allow), limited to what Interface Builder/Autolayout and static resources can support. Apple discourages making it dramatically different from first screen of your app to avoid visual jump.| Everything allowed: dynamic content, logic, navigation, etc.|


# add text to start screen

1. Open the Object Library via View->Show Library.
2. Drag a label to the view and center with UI.
