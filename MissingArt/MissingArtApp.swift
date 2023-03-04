//
//  MissingArtApp.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import LoadingState
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

  private func reportError(_ error: FixArtError) {
    fixArtError = error
  }

  private func updateProcessingState(
    _ missingArtwork: MissingArtwork, processingState: ProcessingState
  ) {
    processingStates[missingArtwork] = processingState
  }

  private func fixArtworkAppleScript(
    missingArtwork: MissingArtwork, scriptHandler: () throws -> Bool
  ) {
    updateProcessingState(missingArtwork, processingState: .processing)

    var result: Bool = false
    do {
      result = try scriptHandler()
    } catch {
      reportError(FixArtError.cannotFixArtwork(missingArtwork, error))
    }

    updateProcessingState(missingArtwork, processingState: result ? .success : .failure)
  }

  @ViewBuilder private var copyAppleScriptLabel: some View {
    Text(
      "Copy Fix Art AppleScript",
      comment:
        "Menu Action to copy AppleScript to fix album artwork."
    )
  }

  @ViewBuilder private var fixLabel: some View {
    Text(
      "Fix Art",
      comment: "Menu Action to fix album artwork in process.")
  }

  var body: some Scene {
    WindowGroup {
      MissingArtworkView(processingStates: $processingStates)
        .alert(
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
    }.commands {
      MissingArtworkCommands(
        noArtworkContextMenuBuilder: {
          (missingImages: [(missingArtwork: MissingArtwork, image: NSImage)]) in
          if missingImages.count == 1, let missingImage = missingImages.first {
            Button {
              NSPasteboard.general.add(image: missingImage.image)
            } label: {
              Text(
                "Copy Artwork Image", comment: "Menu Action to copy the selected album image."
              )
            }

            Button {
              let appleScript = MissingArtwork.artworksAppleScript([missingImage.missingArtwork])
              NSPasteboard.general.add(string: appleScript, image: missingImage.image)
            } label: {
              copyAppleScriptLabel
            }
          }

          Button {
            Task {
              guard let script = loadingState.value else {
                debugPrint("Task is running when button should be disabled.")
                return
              }

              for missingImage in missingImages {
                fixArtworkAppleScript(missingArtwork: missingImage.missingArtwork) {
                  return try script.fixArtwork(
                    missingImage.missingArtwork, image: missingImage.image)
                }
              }
            }
          } label: {
            fixLabel
          }.disabled(missingImages.count == 0)
        },
        partialArtworkContextMenuBuilder: { missingArtworks in
          Button {
            let appleScript = MissingArtwork.partialArtworksAppleScript(missingArtworks)
            NSPasteboard.general.add(string: appleScript)
          } label: {
            copyAppleScriptLabel
          }.disabled(missingArtworks.count == 0)

          Button {
            Task {
              guard let script = loadingState.value else {
                debugPrint("Task is running when button should be disabled.")
                return
              }
              for missingArtwork in missingArtworks {
                fixArtworkAppleScript(missingArtwork: missingArtwork) {
                  return try script.fixPartialArtwork(missingArtwork)
                }
              }
            }
          } label: {
            fixLabel
          }.disabled(missingArtworks.count == 0)
        }
      )
    }
  }
}
