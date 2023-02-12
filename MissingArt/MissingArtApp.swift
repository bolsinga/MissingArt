//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

@main
struct MissingArtApp: App {

  @State private var loadingState: LoadingState<AppleScript> = .idle

  @State private var fixArtError: Error?
  @State private var processingStates: [MissingArtwork: ProcessingState] = [:]

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
    _ missingArtwork: MissingArtwork, processingState: ProcessingState
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
            Text("Nothing To Do", comment: "Shown when context menu has nothing to do.")
          case 1:
            if let missingImage = missingImages.first {
              switch missingImage.missingArtwork.availability {
              case .none:
                if let image = missingImage.image {
                  Button {
                    NSPasteboard.general.add(image: image)
                  } label: {
                    Text(
                      "Copy Artwork Image", comment: "Menu Action to copy the selected album image."
                    )
                  }
                  Button {
                    let appleScript = MissingArtwork.artworksAppleScript(
                      [missingImage.missingArtwork], catchAndLogErrors: true)
                    NSPasteboard.general.add(string: appleScript, image: image)
                  } label: {
                    Text(
                      "Copy Art AppleScript",
                      comment:
                        "Menu Action to copy AppleScript to fix album artwork for albums with no artwork."
                    )
                  }
                  Button {
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
                  } label: {
                    Text(
                      "Fix Art",
                      comment: "Menu Action to fix album artwork when there is no artwork.")
                  }
                } else {
                  Text(
                    "No Image Selected",
                    comment:
                      "Text shown when no image is selected and the user selects the option to fix the artwork for an album with none."
                  )
                }
              case .some:
                Button {
                  let appleScript = MissingArtwork.partialArtworksAppleScript(
                    [missingImage.missingArtwork], catchAndLogErrors: true)
                  NSPasteboard.general.add(string: appleScript)
                } label: {
                  Text(
                    "Copy Partial Art AppleScript",
                    comment:
                      "Menu Action to copy AppleScript to fix album artwork for albums with some artwork."
                  )
                }
                Button {
                  Task {
                    guard let script = loadingState.value else {
                      debugPrint("Task is running when button should be disabled.")
                      return
                    }
                    await fixArtworkAppleScript(missingImage: missingImage) {
                      return try await script.fixPartialArtwork(missingImage.missingArtwork)
                    }
                  }
                } label: {
                  Text(
                    "Fix Partial Art",
                    comment: "Menu Action to fix album artwork when there is some artwork.")
                }
              case .unknown:
                Text(
                  "Unknown Artwork Issue",
                  comment:
                    "Text shown when user selects the option to fix artwork for an album with an unknown issue."
                )
              }
            } else {
              fatalError("Count of Missing Images is one, but can't pull off the first item.")
            }
          default:
            let partials = missingImages.filter { $0.missingArtwork.availability == .some }.map {
              $0.missingArtwork
            }
            Button {
              let appleScript = MissingArtwork.partialArtworksAppleScript(
                partials, catchAndLogErrors: true)

              NSPasteboard.general.add(string: appleScript)
            } label: {
              Text(
                "Copy Multiple Partial Art AppleScript",
                comment:
                  "Menu Action to copy AppleScript to fix multiple album's artwork for albums with some artwork."
              )
            }.disabled(partials.count == 0)
          }
        }, processingStates: $processingStates
      ).alert(
        isPresented: .constant(hasError), error: currentError,
        actions: { error in
          Button {
            fixArtError = nil
            if loadingState.isError {
              loadingState = .idle
            }
          } label: {
            Text("OK", comment: "OK button for alert shown when there is an unrecoverable error.")
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
