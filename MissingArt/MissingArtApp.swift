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
}

extension FixArtError: LocalizedError {
  var errorDescription: String? {
    var detail: String
    switch self {
    case .cannotFixPartialArtwork(let missingArtwork, let error):
      detail = "\(missingArtwork.description): \(error.errorDescription ?? "No Description")"
    case .unknownError(let missingArtwork, let error):
      detail = "\(missingArtwork.description): Unknown: \(String(describing: error))"
    }
    return "Unable to change Music artwork image for \(detail)"
  }

  var recoverySuggestion: String? {
    "The artwork was not able to be fixed. Try running as an AppleScript."
  }
}

@main
struct MissingArtApp: App {

  @State private var fixArtError: FixArtError?

  private func copyPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Copy Partial Art AppleScript") {
      let appleScript = MissingArtwork.partialArtworksAppleScript(
        [missingArtwork], catchAndLogErrors: true)
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  private func copyArtButton(_ missingArtwork: MissingArtwork, image: NSImage) -> some View {
    Button("Copy Art AppleScript") {
      let appleScript = MissingArtwork.artworksAppleScript(
        [missingArtwork], catchAndLogErrors: true)
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      // Put the image on the clipboard for the script. Needs to be first.
      pasteboard.writeObjects([image])
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  @MainActor private func reportError(_ error: FixArtError) {
    fixArtError = error
  }

  private func fixPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Fix Partial Art") {
      Task {
        do {
          try MissingArtwork.fixPartialArtwork(missingArtwork)
        } catch let error as LocalizedError {
          await reportError(FixArtError.cannotFixPartialArtwork(missingArtwork, error))
        } catch {
          await reportError(FixArtError.unknownError(missingArtwork, error))
        }
      }
    }
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
                  let pasteboard = NSPasteboard.general
                  pasteboard.clearContents()
                  pasteboard.writeObjects([image])
                }
                copyArtButton(missingImage.missingArtwork, image: image)
              } else {
                Text("No Image Selected")
              }
            case .some:
              copyPartialArtButton(missingImage.missingArtwork)
              fixPartialArtButton(missingImage.missingArtwork)
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

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(appleScript, forType: .string)
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
    }
  }
}
