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
  private var model = Model()

  var body: some Scene {
    WindowGroup {
      ContentView(missingArtworks: model.missingArtworks)
    }
  }
}
