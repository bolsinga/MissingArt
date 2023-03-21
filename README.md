# Missing Artwork
<img src="https://raw.github.com/bolsinga/MissingArt/main/MissingArt/Assets.xcassets/AppIcon.appiconset/Icon.png" width="100">

Missing Artwork is a macOS application that will find music media in Music.app that does not have artwork. It will also find albums where some files have artwork and some do not. Once these have been identified, the application can fix the artwork in Music.app for you.

When the application is launched, it will read your Music application data, looking for music media with broken artwork. It will then display all the items found. Some are items with No Artwork, some are items whose album files do not all have artwork, called Partial Artworks. Once an item with No Artwork is selected from the list, it will attempt to load artwork from Apple's Music Catalog. Select the image you wish to use for the repair. If an item with Partial Artwork is selected, it will show the image already found. From the Repair Menu, you can then choose to fix the Partial Artwork or fix No Artwork media, depending upon what you selected. You can also copy the AppleScript code used to do the repair work.

## Developers

Missing Artwork is an app that uses [iTunes Missing Artwork](https://github.com/bolsinga/itunes_missing_artwork). This separate Xcode project application is necessary. The Xcode project can set up the proper code signing and entitlements that are not readily available via Swift Packages. You will have to code sign with your Developer Identity, and follow the MusicKit instructions to allow your app to access MusicKit API.

### AppleScript

Missing Artwork uses AppleScript to change data in Music.app. The iTunes Library framework on macOS does not have "write" capabilities. The MusicKit framework on macOS does not have a connection to Music.app. So this has some hand rolled AppleScript to do the work. AppleScript is still supported in macOS, but the documentation (and syntax) for this technology is lacking. It took quite a bit of tinkering to get this to work. I left the code in for "Copy AppleScript" from the application, mostly since it is useful for debugging this part of the code when it does not work.

### Integrating iTunes Missing Artwork

The logic for finding and displaying the missing artwork is in [iTunes Missing Artwork](https://github.com/bolsinga/itunes_missing_artwork). The code that repairs the media is delegated to the application via properties on `MissingArtworkCommands`. Use `MissingArtworkView` as your main `View` for your application's `Scene`.

## Privacy

[Privacy Policy](https://www.bolsinga.com/missingart-privacy/)
