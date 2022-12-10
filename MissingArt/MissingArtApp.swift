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

  private let appleScriptFixAlbumArtFunctionDefinition = """
    on clipboardImage(ignored)
      set imageData to missing value
      if ((clipboard info) as string) contains "«class PNGf»" then
        set imageData to (the clipboard as «class PNGf»)
      end if
      return imageData
    end clipboardImage
    on findPartialImage(results)
      set imageData to missing value
      tell application "Music"
        repeat with trk in results
          if (count of artworks of trk) is not 0 then
            set imageData to data of item 1 of artworks of trk
            exit repeat
          end if
        end repeat
      end tell
      return imageData
    end findPartialImage
    on verifyTrack(trk, albumString, artistString)
      set matches to false
      tell application "Music"
        set matches to album of trk is equal to albumString
        if matches is true and length of artistString is not 0 then
          set matches to artist of trk is equal to artistString
        end if
      end tell
      return matches
    end verifyTrack
    on fixAlbumArtwork(searchString, albumString, artistString, findImageInTracks)
      tell application "Music"
        global findImageHandler
        set findImageHandler to missing value
        if findImageInTracks is true then
          set findImageHandler to findPartialImage
        else
          set findImageHandler to clipboardImage
        end if
        try
          set unfilteredResults to search the first library playlist for searchString
        on error errorString number errorNumber
          error "Cannot find " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 501
        end try
        set results to {}
        repeat with trk in unfilteredResults
          if my verifyTrack(trk, albumString, artistString) then
            set the end of results to trk
          end if
        end repeat
        set imageData to my findImageHandler(results)
        if imageData is missing value then
          set message to "Cannot find image data for " & searchString
          error message number 502
        end if
        repeat with trk in results
          try
            set artwrks to artworks of trk
            if artwrks is missing value then
              delete artworks of trk
            else if length of artwrks is 0 then
              delete artworks of trk
            end if
          on error errorString number errorNumber
            error "Cannot reset artwork for: " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 503
          end try
          try
            set data of artwork 1 of trk to imageData
          on error errorString number errorNumber
            error "Cannot set artwork for: " & searchString & " (" & errorString & " " & (errorNumber as string) & ")" number 504
          end try
        end repeat
      end tell
    end fixAlbumArtwork

    """

  private func _artworksAppleScript(
    _ missingArtworks: [MissingArtwork], caller: ((MissingArtwork) -> String)
  ) -> String {
    var appleScript = """
      \(appleScriptFixAlbumArtFunctionDefinition)

      """
    for missingArtwork in missingArtworks {
      appleScript.append(
        """
        try
          \(caller(missingArtwork))
        on error errorString
          log \"Error Trying to Fix Artwork: \" & errorString
        end try

        """)
    }
    appleScript.append(
      """
      return true
      """)
    return appleScript
  }

  private func partialArtworksAppleScript(_ missingArtworks: [MissingArtwork]) -> String {
    return _artworksAppleScript(missingArtworks) { missingArtwork in
      missingArtwork.appleScriptCodeToFixPartialArtworkCall
    }
  }

  private func artworksAppleScript(_ missingArtworks: [MissingArtwork]) -> String {
    return _artworksAppleScript(missingArtworks) { missingArtwork in
      missingArtwork.appleScriptCodeToFixArtworkCall
    }
  }

  private func copyPartialArtButton(_ missingArtwork: MissingArtwork) -> some View {
    Button("Copy Partial Art AppleScript") {
      let appleScript = partialArtworksAppleScript([missingArtwork])
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(appleScript, forType: .string)
    }
  }

  private func copyArtButton(_ missingArtwork: MissingArtwork, image: NSImage) -> some View {
    Button("Copy Art AppleScript") {
      let appleScript = artworksAppleScript([missingArtwork])
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
    let exec = NSAppleScript(source: partialArtworksAppleScript([missingArtwork]))
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
            let appleScript = partialArtworksAppleScript(partials)

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
