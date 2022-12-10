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

  private var appleScriptVerificationParameters: String {
    switch self {
    case .ArtistAlbum(let artist, let album):
      return "\"\(album.escapeQuotes)\", \"\(artist.escapeQuotes)\""
    case .CompilationAlbum(let album):
      return "\"\(album.escapeQuotes)\", \"\""
    }
  }

  private func appleScriptCodeToFixArtworkCall(_ findImageHandler: String) -> String {
    return """
          fixAlbumArtwork(\"\(appleScriptSearchRepresentation)\", \(appleScriptVerificationParameters), \(findImageHandler))
      """
  }

  var appleScriptCodeToFixPartialArtworkCall: String {
    return appleScriptCodeToFixArtworkCall("true")
  }

  var appleScriptCodeToFixArtworkCall: String {
    return appleScriptCodeToFixArtworkCall("false")
  }
}

enum FixArtError: Error {
  case appleScriptCannotExec(MissingArtwork)
  case appleScriptFailure(MissingArtwork, String)
  case appleScriptIssue(MissingArtwork)
  case unknownError(MissingArtwork, Error)
}

extension FixArtError {
  static func createAppleScriptError(
    missingArtwork: MissingArtwork, nsDictionary: NSDictionary
  )
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
