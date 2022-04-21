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
  var missingArtworks: [MissingArtwork] {
    do {
      return Array(Set<MissingArtwork>(try MissingArtwork.gatherMissingArtwork()))
    } catch {
      return []
    }
  }
  var body: some Scene {
    WindowGroup {
      ContentView(missingArtworks: missingArtworks)
    }
  }
}
