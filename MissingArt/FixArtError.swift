//
//  FixArtError.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 2/10/23.
//

import Foundation
import MissingArtwork

enum FixArtError: Error {
  case cannotFixArtwork(MissingArtwork, Error)
}

extension FixArtError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .cannotFixArtwork(let missingArtwork, let error):
      return
        "Unable to change Music artwork image for \(missingArtwork.description): \(error.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .cannotFixArtwork(_, _):
      return "The artwork was not able to be fixed. Try running as an AppleScript."
    }
  }
}
