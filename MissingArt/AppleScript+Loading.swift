//
//  AppleScript+Loading.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 1/22/23.
//

#if canImport(AppKit)
  import Foundation
  import MissingArtwork

  private enum LoadScriptError: Error {
    case cannotInitializeScript(Error)
  }

  extension LoadScriptError: LocalizedError {
    var errorDescription: String? {
      switch self {
      case .cannotInitializeScript(let error):
        return String(
          localized: "AppleScript Initialization Error: \(error.localizedDescription)",
          comment: "Error message when AppleScript cannot be initialized by the application.")
      }
    }

    var recoverySuggestion: String? {
      switch self {
      case .cannotInitializeScript(_):
        return String(
          localized:
            "AppleScript cannot be initialized. Use the AppleScript Editor to run scripts.",
          comment: "Recovery message when AppleScript cannot be initialized by the application.")
      }
    }
  }

  extension AppleScript {
    static func load() async throws -> Self {
      do {
        return try await MissingArtwork.createScript()
      } catch {
        throw LoadScriptError.cannotInitializeScript(error)
      }
    }
  }
#endif
