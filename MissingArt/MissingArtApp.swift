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
  private let model = Model()

  @StateObject private var parts = TokenParts()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model, token: parts.token ?? "")
        .sheet(isPresented: $parts.invalid) {
          DeveloperToken(parts: parts)
        }
    }
  }
}
