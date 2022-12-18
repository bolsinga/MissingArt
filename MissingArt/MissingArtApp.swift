//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

private enum FixArtError: Error {
  case cannotFixPartialArtwork(MissingArtwork, LocalizedError)
  case unknownError(MissingArtwork, Error)
  case cannotInitializeScript(LocalizedError)
  case unknownScriptInitializationError(Error)
}

extension FixArtError: LocalizedError {
  var errorDescription: String? {
    var detail: String
    switch self {
    case .cannotFixPartialArtwork(let missingArtwork, let error):
      detail = "\(missingArtwork.description): \(error.errorDescription ?? "No Description")"
    case .unknownError(let missingArtwork, let error):
      detail = "\(missingArtwork.description): Unknown: \(String(describing: error))"
    case .cannotInitializeScript(let error):
      detail = "Script Initialization Error: \(error.errorDescription ?? "No Description")"
    case .unknownScriptInitializationError(let error):
      detail = "Unknown Script Initialization Error: \(String(describing: error))"
    }
    return "Unable to change Music artwork image for \(detail)"
  }

  var recoverySuggestion: String? {
    "The artwork was not able to be fixed. Try running as an AppleScript."
  }
}

@main
struct MissingArtApp: App {

  @State private var script: AppleScript?

  @State private var fixArtError: FixArtError?

  private func addToPasteboard(string: String = "", image: NSImage? = nil) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    // Put the image on the clipboard first, then the text.
    if let image = image {
      pasteboard.writeObjects([image])
    }
    if string.count > 0 {
      pasteboard.setString(string, forType: .string)
    }
  }

  @MainActor private func reportError(_ error: FixArtError) {
    fixArtError = error
  }

  var body: some Scene {
    WindowGroup {
      MissingArtworkView(imageContextMenuBuilder: {
        (missingImages: [MissingArtworkView.MissingImage]) in
        switch missingImages.count {
        case 0:
          Text("Nothing To Do")
        case 1:
          if let missingImage = missingImages.first {
            switch missingImage.availability {
            case .none:
              if let image = missingImage.image {
                Button("Copy Artwork Image") {
                  addToPasteboard(image: image)
                }
                Button("Copy Art AppleScript") {
                  let appleScript = MissingArtwork.artworksAppleScript(
                    [missingImage.missingArtwork], catchAndLogErrors: true)
                  addToPasteboard(string: appleScript, image: image)
                }
              } else {
                Text("No Image Selected")
              }
            case .some:
              Button("Copy Partial Art AppleScript") {
                let appleScript = MissingArtwork.partialArtworksAppleScript(
                  [missingImage.missingArtwork], catchAndLogErrors: true)
                addToPasteboard(string: appleScript)
              }
              Button("Fix Partial Art") {
                Task {
                  do {
                    try await script?.fixPartialArtwork(missingImage.missingArtwork)
                  } catch let error as LocalizedError {
                    reportError(
                      FixArtError.cannotFixPartialArtwork(missingImage.missingArtwork, error))
                  } catch {
                    reportError(FixArtError.unknownError(missingImage.missingArtwork, error))
                  }
                }
              }
            case .unknown:
              Text("Unknown Artwork Issue")
            }
          } else {
            Text("Nothing To Do")
          }
        default:
          let partials = missingImages.filter { $0.availability == .some }.map { $0.missingArtwork }
          Button("Copy Multiple Partial Art AppleScript") {
            let appleScript = MissingArtwork.partialArtworksAppleScript(
              partials, catchAndLogErrors: true)

            addToPasteboard(string: appleScript)
          }.disabled(partials.count == 0)
        }
      }).alert(
        isPresented: .constant(fixArtError != nil), error: fixArtError,
        actions: { error in
          Button("OK") {
            fixArtError = nil
          }
        },
        message: { error in
          Text(error.recoverySuggestion ?? "")
        }
      )
      .task {
        do {
          script = try await MissingArtwork.createScript()
        } catch let error as LocalizedError {
          reportError(FixArtError.cannotInitializeScript(error))
        } catch {
          reportError(FixArtError.unknownScriptInitializationError(error))
        }
      }
    }
  }
}
