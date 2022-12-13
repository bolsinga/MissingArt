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

  @State private var fixArtError: FixArtError?
  @State private var showUnableToFixPartialArt: Bool = false

  private func copyPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Copy Partial Art AppleScript") {
      let appleScript = MissingArtwork.partialArtworksAppleScript([missingArtwork])
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  private func copyArtButton(_ missingArtwork: MissingArtwork, image: NSImage) -> some View {
    Button("Copy Art AppleScript") {
      let appleScript = MissingArtwork.artworksAppleScript([missingArtwork])
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      // Put the image on the clipboard for the script. Needs to be first.
      pasteboard.writeObjects([image])
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  @MainActor private func reportError(_ error: FixArtError) {
    fixArtError = error
    showUnableToFixPartialArt = true
  }

  private func fixPartialArtwork(_ missingArtwork: MissingArtwork) throws {
    let exec = NSAppleScript(source: MissingArtwork.partialArtworksAppleScript([missingArtwork]))
    if let exec = exec {
      var errorDictionary: NSDictionary?
      _ = exec.executeAndReturnError(&errorDictionary)
      if let errorDictionary = errorDictionary {
        throw FixArtError.createAppleScriptError(
          missingArtwork: missingArtwork, nsDictionary: errorDictionary)
      }
    } else {
      throw FixArtError.appleScriptCannotExec(missingArtwork)
    }
  }

  private func fixPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Fix Partial Art") {
      Task {
        do {
          try fixPartialArtwork(missingArtwork)
        } catch let error as FixArtError {
          await reportError(error)
        } catch {
          await reportError(.unknownError(missingArtwork, error))
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
            let appleScript = MissingArtwork.partialArtworksAppleScript(partials)

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(appleScript, forType: .string)
          }.disabled(partials.count == 0)
        }
      }).alert(
        isPresented: $showUnableToFixPartialArt, error: fixArtError,
        actions: { error in
          Button("OK") {
            showUnableToFixPartialArt = false
          }
        },
        message: { error in
          Text("The partial artwork was not able to be fixed. Try running as an AppleScript.")
        }
      )
    }
  }
}
