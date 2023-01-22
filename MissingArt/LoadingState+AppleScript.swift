//
//  LoadingState+AppleScript.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 1/22/23.
//

import Foundation
import MissingArtwork

private enum LoadScriptError: Error {
  case cannotInitializeScript(Error)
}

extension LoadScriptError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .cannotInitializeScript(let error):
      return "AppleScript Initialization Error: \(error.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .cannotInitializeScript(_):
      return "AppleScript cannot be initialized. Use AppleScript Editor to run scripts."
    }
  }
}

extension LoadingState where Value == AppleScript {
  mutating func load() async {
    guard case .idle = self else {
      return
    }

    self = .loading

    do {
      let script = try await MissingArtwork.createScript()

      self = .loaded(script)
    } catch {
      self = .error(LoadScriptError.cannotInitializeScript(error))
    }
  }
}
