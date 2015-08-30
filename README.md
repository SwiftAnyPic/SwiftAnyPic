[![](https://img.shields.io/github/issues-raw/kwkhaw/SwiftAnyPic.svg)]()
[![GitHub license](https://img.shields.io/github/license/kwkhaw/SwiftAnyPic.svg)]()

# SwiftAnyPic
Swift port of AnyPic project [https://github.com/ParsePlatform/Anypic](https://github.com/ParsePlatform/Anypic)

## Requirements
This application requires Xcode 7 and the iOS SDK v9.0.

* Developed on Xcode 7 beta 6.
* Tested only with Simulator iPhone 5s.

## Setup
1. Install all project dependencies from [CocoaPods](http://cocoapods.org/#install) by running this script: ```pod install```
2. Open the Xcode workspace Anypic.xcworkspace
3. Create your Anypic App on [Parse](https://parse.com/apps)
4. Copy your new app's application id and client key into ```AppDelegate.swift```:
```Parse.setApplicationId("APPLICATION_ID", clientKey: "CLIENT_KEY")```

### Configuring Anypic's Facebook integration
1. Set up a Facebook app at [http://developers.facebook.com/apps](http://developers.facebook.com/apps)
2. Set up a URL scheme for fbFACEBOOK_APP_ID, where FACEBOOK_APP_ID is your Facebook app's id.
3. Add your Facebook app id to ```Info.plist``` in the ```FacebookAppID``` key.

**Note: By using the original Parse application ID, client key and the Facebook App ID in the source code, the app will connect to the Parse and Facebook apps which the App Store's AnyPic app is using.**

## TODO
This project is still work in progress. There are quite a lot of things need to be fixed.

* Many iOS APIs used in the objective-C version are already deprecated. They need to be replaced with the latest APIs.
* I encountered some strange crashes in Bolts. Same error as described in [https://github.com/BoltsFramework/Bolts-iOS/issues/102](https://github.com/BoltsFramework/Bolts-iOS/issues/102). I temporarily used the workaround mentioned by [https://github.com/wdcurry](https://github.com/wdcurry).
* We need @3x images for iPhone 6 Plus (so far I just tested on Simulator iPhone 5s only).
* I basically just converted the Objective-C syntax to Swift syntax for most of the code whenever possible. So there are still rooms for improvement to make the code more "Swifty".
* etc.

## Misc
Please feel free to contribute! :-)

