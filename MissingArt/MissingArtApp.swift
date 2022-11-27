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
    "verify_track_\(String(simpleRepresentation.compactMap{ $0.isLetter || $0.isNumber ? $0 : "_" }).folding(options: .diacriticInsensitive, locale: .current))"
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

struct FixArtError: LocalizedError {
  let message: String

  init(nsDictionary: NSDictionary) {
    let message = nsDictionary[NSAppleScript.errorMessage] as? String
    if let message = message {
      self.message = message
    } else {
      self.message = "Unknown Error"
    }
  }

  init(message: String) {
    self.message = message
  }

  var errorDescription: String? {
    message
  }

  var failureReason: String? {
    message
  }

  var recoverySuggestion: String? {
    "Try running as an AppleScript."
  }
}

@main
struct MissingArtApp: App {

  @State private var fixArtError: FixArtError?
  @State private var showUnableToFixPartialArt: Bool = false

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

  private func partialArtworkAppleScript(_ missingArtwork: MissingArtwork) -> String {
    return """
      \(appleScriptFixPartialAlbumFunctionDefinition)
      \(missingArtwork.appleScriptCodeToFixPartialArtwork)
      return true
      """
  }

  private func copyPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Copy Partial Art AppleScript") {
      let appleScript = partialArtworkAppleScript(missingArtwork)
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  private func fixPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Fix Partial Art") {
      let exec = NSAppleScript(source: partialArtworkAppleScript(missingArtwork))
      if let exec = exec {
        var errorDictionary: NSDictionary?
        _ = exec.executeAndReturnError(&errorDictionary)
        if let errorDictionary = errorDictionary {
          fixArtError = FixArtError(nsDictionary: errorDictionary)
          showUnableToFixPartialArt = true
        }
      } else {
        fixArtError = FixArtError(message: "Unable to change Music artwork image.")
        showUnableToFixPartialArt = true
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      MissingArtworkView(imageContextMenuBuilder: { missingArtwork, availability, image in
        switch availability {
        case .none:
          if let image = image {
            Button("Copy Artwork Image") {
              let pasteboard = NSPasteboard.general
              pasteboard.clearContents()
              pasteboard.writeObjects([image])
            }
          } else {
            Text("No Image Selected")
          }
        case .some:
          copyPartialArtButton(missingArtwork)
          fixPartialArtButton(missingArtwork)
        case .unknown:
          Text("Unknown Artwork Issue")
        }
      }).alert(
        isPresented: $showUnableToFixPartialArt, error: fixArtError,
        actions: { error in
          Button("OK") {
            showUnableToFixPartialArt = false
          }
        },
        message: { error in
          Text("The partial artwork was not able to be fixed. Try running as an AppleScript.")
        }
      )
    }
  }
}
