# Missing Artwork
<img src="https://raw.github.com/bolsinga/MissingArt/main/MissingArt/Assets.xcassets/AppIcon.appiconset/Icon.png" width="100">

Missing Artwork is the app that uses [iTunes Missing Artwork](https://github.com/bolsinga/itunes_missing_artwork).

This separate Xcode project repository is necessary. The Xcode project can set up the proper code signing and entitlements that are not (easily?) available via Swift Packages. Pretty much the entire application is in the Swift Package however.

You will have to code sign with your Developer Identity, and follow the MusicKit instructions to allow your app to access MusicKit API.

[Privacy Policy](https://www.bolsinga.com/missingart-privacy/)
