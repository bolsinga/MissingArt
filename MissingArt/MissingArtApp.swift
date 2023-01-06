//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

private enum FixArtError: Error {
  case cannotFixArtwork(MissingArtwork, LocalizedError)
  case unknownError(MissingArtwork, Error)
  case cannotInitializeScript(LocalizedError)
  case unknownScriptInitializationError(Error)
}

extension FixArtError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .cannotFixArtwork(let missingArtwork, let error):
      return
        "Unable to change Music artwork image for \(missingArtwork.description): \(error.errorDescription ?? "No Description")"
    case .unknownError(let missingArtwork, let error):
      return
        "Unable to change Music artwork image for \(missingArtwork.description): Unknown: \(String(describing: error))"
    case .cannotInitializeScript(let error):
      return "AppleScript Initialization Error: \(error.errorDescription ?? "No Description")"
    case .unknownScriptInitializationError(let error):
      return "Unknown AppleScript Initialization Error: \(String(describing: error))"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .cannotFixArtwork(_, _), .unknownError(_, _):
      return "The artwork was not able to be fixed. Try running as an AppleScript."
    case .cannotInitializeScript(_), .unknownScriptInitializationError(_):
      return "AppleScript cannot be initialized. Use AppleScript Editor to run scripts."
    }
  }
}

@main
struct MissingArtApp: App {

  @State private var script: AppleScript?

  @State private var fixArtError: FixArtError?
  @State private var processingStates: [MissingArtwork: Description.ProcessingState] = [:]

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

  @MainActor private func updateProcessingState(
    _ missingArtwork: MissingArtwork, processingState: Description.ProcessingState
  ) {
    processingStates[missingArtwork] = processingState
  }

  private func fixArtworkAppleScript(
    missingImage: MissingArtworkView.MissingImage, scriptHandler: () async throws -> Bool
  ) async {
    await updateProcessingState(
      missingImage.missingArtwork, processingState: .processing)

    var result: Bool = false
    do {
      result = try await scriptHandler()
    } catch let error as LocalizedError {
      await reportError(
        FixArtError.cannotFixArtwork(missingImage.missingArtwork, error))
    } catch {
      await reportError(FixArtError.unknownError(missingImage.missingArtwork, error))
    }

    await updateProcessingState(
      missingImage.missingArtwork, processingState: result ? .success : .failure)
  }

  var body: some Scene {
    WindowGroup {
      MissingArtworkView(
        imageContextMenuBuilder: {
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
                  Button("Fix Art") {
                    Task {
                      guard let script = script else {
                        debugPrint("Task is running when button should be disabled.")
                        return
                      }

                      await fixArtworkAppleScript(missingImage: missingImage) {
                        return try await script.fixArtwork(
                          missingImage.missingArtwork, image: image)
                      }
                    }
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
                    guard let script = script else {
                      debugPrint("Task is running when button should be disabled.")
                      return
                    }
                    await fixArtworkAppleScript(missingImage: missingImage) {
                      return try await script.fixPartialArtwork(missingImage.missingArtwork)
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
            let partials = missingImages.filter { $0.availability == .some }.map {
              $0.missingArtwork
            }
            Button("Copy Multiple Partial Art AppleScript") {
              let appleScript = MissingArtwork.partialArtworksAppleScript(
                partials, catchAndLogErrors: true)

              addToPasteboard(string: appleScript)
            }.disabled(partials.count == 0)
          }
        }, processingStates: $processingStates
      ).alert(
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
