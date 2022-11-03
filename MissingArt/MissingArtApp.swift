//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

extension String {
  var escapeQuotes: String {
    self.replacingOccurrences(of: "\"", with: "\\\"")
  }
}

extension MissingArtwork {
  private var appleScriptSearchRepresentation: String {
    "\(simpleRepresentation)".escapeQuotes
  }

  private var appleScriptVerifyTrackMatch: String {
    switch self {
    case .ArtistAlbum(let artist, let album):
      return
        "album of trk is equal to \"\(album.escapeQuotes)\" and artist of trk is equal to \"\(artist.escapeQuotes)\""
    case .CompilationAlbum(let album):
      return "album of trk is equal to \"\(album.escapeQuotes)\""
    }
  }

  private var appleScriptVerifyTrackFunctionName: String {
    "verify_track_\(String(simpleRepresentation.compactMap{ $0.isLetter ? $0 : "_" }))"
  }

  var appleScriptCodeToFixPartialArtwork: String {
    let appleScriptVerifyTrackFunctionName = appleScriptVerifyTrackFunctionName
    return """
          on \(appleScriptVerifyTrackFunctionName)(trk)
          set matches to false
          tell application "Music"
            set matches to \(appleScriptVerifyTrackMatch)
          end tell
          return matches
          end \(appleScriptVerifyTrackFunctionName)
          fixPartialAlbum(\"\(appleScriptSearchRepresentation)\", \(appleScriptVerifyTrackFunctionName))
      """
  }
}

@main
struct MissingArtApp: App {
  let appleScriptFixPartialAlbumFunctionDefinition = """
    on fixPartialAlbum(searchString, uncallableTrackTest)
      global trackTest
      set trackTest to uncallableTrackTest
      tell application "Music"
        set unfilteredResults to search the first library playlist for searchString
      end tell
      set results to {}
      repeat with trk in unfilteredResults
        if trackTest(trk) then
          set the end of results to trk
        end if
      end repeat
      set imageData to missing value
      repeat with trk in results
        tell application "Music"
          if (count of artworks of trk) is not 0 then
            set imageData to raw data of item 1 of artworks of trk
            log "found artwork"
            exit repeat
          end if
        end tell
      end repeat
      if imageData is missing value then
        log "cannot find artwork"
      end if
      repeat with trk in results
        set artwrk to missing value
        tell application "Music"
          if artworks of trk is not missing value then
            set artwrk to item 1 of artworks of trk
          end if
        end tell
        if artwrk is missing value then
          log "no artwork for " & name of trk
        end if
        if artwrk is not missing value then
          tell application "Music"
            set raw data of artwrk to imageData
          end tell
        end if
      end repeat
    end fixPartialAlbum
    """
  var body: some Scene {
    WindowGroup {
      MissingArtworkView { missingArtwork in
        Button("Copy Partial Art AppleScript") {
          let appleScript = """
            \(appleScriptFixPartialAlbumFunctionDefinition)
            \(missingArtwork.appleScriptCodeToFixPartialArtwork)
            """
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(appleScript, forType: .string)
        }
      }
    }
  }
}
