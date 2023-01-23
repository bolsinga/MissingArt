//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

private enum FixArtError: Error {
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

@main
struct MissingArtApp: App {

  @State private var loadingState: LoadingState<AppleScript> = .idle

  @State private var fixArtError: Error?
  @State private var processingStates: [MissingArtwork: Description.ProcessingState] = [:]

  private func addToPasteboard(string: String = "", image: NSImage? = nil) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    // Put the image on the clipboard first, then the text.
    if let image {
      pasteboard.writeObjects([image])
    }
    if string.count > 0 {
      pasteboard.setString(string, forType: .string)
    }
  }

  var hasError: Bool {
    return fixArtError != nil || loadingState.isError
  }

  var currentError: WrappedLocalizedError? {
    if let error = fixArtError {
      return WrappedLocalizedError.wrapError(error: error)
    }
    return loadingState.currentError
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
    missingImage: (missingArtwork: MissingArtwork, image: NSImage?),
    scriptHandler: () async throws -> Bool
  ) async {
    await updateProcessingState(
      missingImage.missingArtwork, processingState: .processing)

    var result: Bool = false
    do {
      result = try await scriptHandler()
    } catch {
      await reportError(
        FixArtError.cannotFixArtwork(missingImage.missingArtwork, error))
    }

    await updateProcessingState(
      missingImage.missingArtwork, processingState: result ? .success : .failure)
  }

  var body: some Scene {
    WindowGroup {
      MissingArtworkView(
        imageContextMenuBuilder: {
          (missingImages: [(missingArtwork: MissingArtwork, image: NSImage?)]) in
          switch missingImages.count {
          case 0:
            Text("Nothing To Do")
          case 1:
            if let missingImage = missingImages.first {
              switch missingImage.missingArtwork.availability {
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
                      guard let script = loadingState.value else {
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
                    guard let script = loadingState.value else {
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
            let partials = missingImages.filter { $0.missingArtwork.availability == .some }.map {
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
        isPresented: .constant(hasError), error: currentError,
        actions: { error in
          Button("OK") {
            fixArtError = nil
            if loadingState.isError {
              loadingState = .idle
            }
          }
        },
        message: { error in
          Text(error.recoverySuggestion ?? "")
        }
      )
      .task {
        await loadingState.load()
      }
    }
  }
}
