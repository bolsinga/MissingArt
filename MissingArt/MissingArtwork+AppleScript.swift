//
//  MissingArtwork+AppleScript.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 12/10/22.
//

import Foundation
import MissingArtwork

extension String {
  fileprivate var escapeQuotes: String {
    self.replacingOccurrences(of: "\"", with: "\\\"")
  }
}

extension MissingArtwork {
  private var appleScriptSearchRepresentation: String {
    "\(simpleRepresentation)".escapeQuotes
  }

  private var appleScriptVerificationParameters: (String, String) {
    switch self {
    case .ArtistAlbum(let artist, let album):
      return (album.escapeQuotes, artist.escapeQuotes)
    case .CompilationAlbum(let album):
      return (album.escapeQuotes, "")
    }
  }

  private func appleScriptCodeToFixArtworkCall(_ parameters: (String, String, String, String, Bool))
    -> String
  {
    return """
          \(parameters.0)(\"\(parameters.1)\", \"\(parameters.2)\", \"\(parameters.3)\", \(parameters.4))
      """
  }

  private var fixAlbumArtworkHandler: String {
    "fixAlbumArtwork"
  }

  fileprivate var appleScriptFixPartialArtworkParameters: (String, String, String, String, Bool) {
    let params = appleScriptVerificationParameters
    return (fixAlbumArtworkHandler, appleScriptSearchRepresentation, params.0, params.1, true)
  }

  fileprivate var appleScriptFixArtworkParameters: (String, String, String, String, Bool) {
    let params = appleScriptVerificationParameters
    return (fixAlbumArtworkHandler, appleScriptSearchRepresentation, params.0, params.1, false)
  }

  private var appleScriptCodeToFixPartialArtworkCall: String {
    return appleScriptCodeToFixArtworkCall(appleScriptFixPartialArtworkParameters)
  }

  private var appleScriptCodeToFixArtworkCall: String {
    return appleScriptCodeToFixArtworkCall(appleScriptFixArtworkParameters)
  }
}

extension MissingArtwork {
  private static let appleScriptFixAlbumArtFunctionDefinition = """
    on clipboardImage(ignored)
      set imageData to missing value
      if ((clipboard info) as string) contains "«class PNGf»" then
        set imageData to (the clipboard as «class PNGf»)
      end if
      return imageData
    end clipboardImage
    on findPartialImage(results)
      set imageData to missing value
      tell application "Music"
        repeat with trk in results
          if (count of artworks of trk) is not 0 then
            set imageData to data of item 1 of artworks of trk
            exit repeat
          end if
        end repeat
      end tell
      return imageData
    end findPartialImage
    on verifyTrack(trk, albumString, artistString)
      set matches to false
      tell application "Music"
        set matches to album of trk is equal to albumString
        if matches is true and length of artistString is not 0 then
          set matches to artist of trk is equal to artistString
        end if
      end tell
      return matches
    end verifyTrack
    on fixAlbumArtwork(searchString, albumString, artistString, findImageInTracks)
      tell application "Music"
        global findImageHandler
        set findImageHandler to missing value
        if findImageInTracks is true then
          set findImageHandler to findPartialImage
        else
          set findImageHandler to clipboardImage
        end if
        try
          set unfilteredResults to search the first library playlist for searchString
        on error errorString number errorNumber
          error "Cannot find " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 501
        end try
        set results to {}
        repeat with trk in unfilteredResults
          if my verifyTrack(trk, albumString, artistString) then
            set the end of results to trk
          end if
        end repeat
        set imageData to my findImageHandler(results)
        if imageData is missing value then
          set message to "Cannot find image data for " & searchString
          error message number 502
        end if
        repeat with trk in results
          try
            set artwrks to artworks of trk
            if artwrks is missing value then
              delete artworks of trk
            else if length of artwrks is 0 then
              delete artworks of trk
            end if
          on error errorString number errorNumber
            error "Cannot reset artwork for: " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 503
          end try
          try
            set data of artwork 1 of trk to imageData
          on error errorString number errorNumber
            error "Cannot set artwork for: " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 504
          end try
        end repeat
      end tell
      return true
    end fixAlbumArtwork

    """

  private static func _artworksAppleScript(
    _ missingArtworks: [MissingArtwork],
    catchAndLogErrors: Bool,
    caller: ((MissingArtwork) -> String)
  ) -> String {
    var appleScript = """
      \(appleScriptFixAlbumArtFunctionDefinition)

      """
    for missingArtwork in missingArtworks {
      if catchAndLogErrors {
        appleScript.append(
          """
          try
            \(caller(missingArtwork))
          on error errorString
            log \"Error Trying to Fix Artwork: \" & errorString
          end try

          """)
      } else {
        appleScript.append(
          """
            \(caller(missingArtwork))

          """)
      }
    }
    appleScript.append(
      """
      return true
      """)
    return appleScript
  }

  public static func partialArtworksAppleScript(
    _ missingArtworks: [MissingArtwork], catchAndLogErrors: Bool
  ) -> String {
    return _artworksAppleScript(missingArtworks, catchAndLogErrors: catchAndLogErrors) {
      missingArtwork in
      missingArtwork.appleScriptCodeToFixPartialArtworkCall
    }
  }

  public static func artworksAppleScript(
    _ missingArtworks: [MissingArtwork], catchAndLogErrors: Bool
  ) -> String {
    return _artworksAppleScript(missingArtworks, catchAndLogErrors: catchAndLogErrors) {
      missingArtwork in
      missingArtwork.appleScriptCodeToFixArtworkCall
    }
  }
}

extension MissingArtwork {
  static func createScript() async throws -> AppleScript {
    try AppleScript(source: MissingArtwork.appleScriptFixAlbumArtFunctionDefinition)
  }
}

extension AppleScript {
  func fixPartialArtwork(_ missingArtwork: MissingArtwork) async throws -> Bool {
    let params = missingArtwork.appleScriptFixPartialArtworkParameters
    return try self.run(
      handler: params.0,
      parameters: params.1, params.2, params.3, params.4)
  }

  func fixArtwork(_ missingArtwork: MissingArtwork) async throws -> Bool {
    let params = missingArtwork.appleScriptFixArtworkParameters
    return try self.run(handler: params.0, parameters: params.1, params.2, params.3, params.4)
  }
}
