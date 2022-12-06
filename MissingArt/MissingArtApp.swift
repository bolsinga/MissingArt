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

      """
  }

  var appleScriptCodeToFixPartialArtworkCall: String {
    return """
          fixAlbumArtwork(\"\(appleScriptSearchRepresentation)\", \(appleScriptVerifyTrackFunctionName), findPartialImage)
      """
  }
}

enum FixArtError: Error {
  case appleScriptCannotExec(MissingArtwork)
  case appleScriptFailure(MissingArtwork, String)
  case appleScriptIssue(MissingArtwork)
  case unknownError(MissingArtwork, Error)
}

extension FixArtError {
  static func createAppleScriptError(missingArtwork: MissingArtwork, nsDictionary: NSDictionary)
    -> FixArtError
  {
    if let message = nsDictionary[NSAppleScript.errorMessage] as? String {
      return .appleScriptFailure(missingArtwork, message)
    }
    return .appleScriptIssue(missingArtwork)
  }
}

extension FixArtError: CustomStringConvertible {
  var description: String {
    var detail: String
    switch self {
    case .appleScriptCannotExec(let missingArtwork):
      detail = "\(missingArtwork.description). Cannot execute AppleScript."
    case .appleScriptFailure(let missingArtwork, let description):
      detail = "\(missingArtwork.description) \(description)"
    case .appleScriptIssue(let missingArtwork):
      detail = "\(missingArtwork.description). AppleScript does not have an identifiable error."
    case .unknownError(let missingArtwork, let error):
      detail = "\(missingArtwork.description). Unknown error: \(String(describing: error))."
    }
    return "Unable to change Music artwork image for \(detail)"
  }
}

extension FixArtError: LocalizedError {
  var errorDescription: String? {
    return self.description
  }
}

@main
struct MissingArtApp: App {

  @State private var fixArtError: FixArtError?
  @State private var showUnableToFixPartialArt: Bool = false

  let appleScriptFixPartialAlbumFunctionDefinition = """
    on findPartialImage(results)
      set imageData to missing value
      repeat with trk in results
        tell application "Music"
          if (count of artworks of trk) is not 0 then
            set imageData to data of item 1 of artworks of trk
            exit repeat
          end if
        end tell
      end repeat
      return imageData
    end findPartialImage
    on fixAlbumArtwork(searchString, uncallableTrackTest, uncallableFindImageHandler)
      global trackTest
      set trackTest to uncallableTrackTest
      global findImageHandler
      set findImageHandler to uncallableFindImageHandler
      tell application "Music"
        try
          set unfilteredResults to search the first library playlist for searchString
        on error errorString number errorNumber
          error "Cannot find " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 501
        end try
      end tell
      set results to {}
      repeat with trk in unfilteredResults
        if trackTest(trk) then
          set the end of results to trk
        end if
      end repeat
      set imageData to findImageHandler(results)
      if imageData is missing value then
        set message to "Cannot find image data for " & searchString
        error message number 502
      end if
      repeat with trk in results
        set artwrk to missing value
        tell application "Music"
          try
            if artworks of trk is not missing value then
              set artwrk to item 1 of artworks of trk
            end if
          on error errorString number errorNumber
            error "Cannot get artwork for: " & name of trk & " (" & errorString & " " & (errorNumber as string) & ")" number 503
          end try
        end tell
        if artwrk is missing value then
          set message to "No artwork for " & name of trk
          error message number 504
        else
          tell application "Music"
            try
              set data of artwrk to imageData
            on error errorString number errorNumber
              error "Cannot set artwork for: " & name of trk & " (" & errorString & " " & (errorNumber as string) & ")" number 505
            end try
          end tell
        end if
      end repeat
    end fixAlbumArtwork

    """

  private func partialArtworksAppleScript(_ missingArtworks: [MissingArtwork]) -> String {
    var appleScript = """
      \(appleScriptFixPartialAlbumFunctionDefinition)

      """
    var calls = ""
    for missingArtwork in missingArtworks {
      appleScript.append(missingArtwork.appleScriptCodeToFixPartialArtworkDefinition)

      calls.append(
        """
        try
          \(missingArtwork.appleScriptCodeToFixPartialArtworkCall)
        on error errorString
          log \"Error Trying to Fix Artwork: \" & errorString
        end try

        """)
    }
    appleScript.append(calls)
    appleScript.append(
      """
      return true
      """)
    return appleScript
  }

  private func copyPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Copy Partial Art AppleScript") {
      let appleScript = partialArtworksAppleScript([missingArtwork])
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  @MainActor private func reportError(_ error: FixArtError) {
    fixArtError = error
    showUnableToFixPartialArt = true
  }

  private func fixPartialArtwork(_ missingArtwork: MissingArtwork) throws {
    let exec = NSAppleScript(source: partialArtworksAppleScript([missingArtwork]))
    if let exec = exec {
      var errorDictionary: NSDictionary?
      _ = exec.executeAndReturnError(&errorDictionary)
      if let errorDictionary = errorDictionary {
        throw FixArtError.createAppleScriptError(
          missingArtwork: missingArtwork, nsDictionary: errorDictionary)
      }
    } else {
      throw FixArtError.appleScriptCannotExec(missingArtwork)
    }
  }

  private func fixPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Fix Partial Art") {
      Task {
        do {
          try fixPartialArtwork(missingArtwork)
        } catch let error as FixArtError {
          await reportError(error)
        } catch {
          await reportError(.unknownError(missingArtwork, error))
        }
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
