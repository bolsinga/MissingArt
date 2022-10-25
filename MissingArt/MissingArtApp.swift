//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

@main
struct MissingArtApp: App {
  var body: some Scene {
    WindowGroup {
      MissingArtworkView { missingArtwork in
        Button("Copy Partial Art AppleScript") {
          let escapedRepresentation = "\(missingArtwork.simpleRepresentation)".replacingOccurrences(of: "\"", with: "\\\"")
          let appleScript = """
            tell application "Music"
              set results to search the first library playlist for "\(escapedRepresentation)"
              set imageData to missing value
              repeat with trk in results
                if (count of artworks of trk) is not 0 then
                  set imageData to raw data of item 1 of artworks of trk
                  exit repeat
                end if
              end repeat
              repeat with trk in results
                set artwrk to item 1 of artworks of trk
                if artwrk is missing value then
                  set raw data of artwrk to imageData
                end if
              end repeat
            end tell
            """
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(appleScript, forType: .string)
        }
      }
    }
  }
}
