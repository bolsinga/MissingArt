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
          let searchStringRepresentation = "\(missingArtwork.simpleRepresentation)"
            .replacingOccurrences(of: "\"", with: "\\\"")
          var trackTest: String
          switch missingArtwork {
          case .ArtistAlbum(let artist, let album):
            trackTest =
              "album of trk is equal to \"\(album)\" and artist of trk is equal to \"\(artist)\" then"
          case .CompilationAlbum(let album):
            trackTest = "album of trk is equal to \"\(album)\" then"
          }
          let appleScript = """
            tell application "Music"
              set unfilteredResults to search the first library playlist for "\(searchStringRepresentation)"
              set results to {}
              repeat with trk in unfilteredResults
                if \(trackTest)
                  set the end of results to trk
                end if
              end repeat
              set imageData to missing value
              repeat with trk in results
                if (count of artworks of trk) is not 0 then
                  set imageData to raw data of item 1 of artworks of trk
                  log "found artwork"
                  exit repeat
                end if
              end repeat
              if imageData is missing value then
                log "cannot find artwork"
              end if
              repeat with trk in results
                set artwrk to missing value
                if artworks of trk is not missing value then
                  set artwrk to item 1 of artworks of trk
                end if
                if artwrk is missing value then
                  log "still no artwork for " & name of trk
                end if
                if artwrk is not missing value then
                  set raw data of artwrk to imageData
                  log "set an artwork"
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
