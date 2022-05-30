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
  @StateObject private var parts = TokenParts()

  var body: some Scene {
    WindowGroup {
      ContentView(token: parts.token ?? "")
        .sheet(isPresented: $parts.requiresTokenRefresh) {
          DeveloperToken(parts: parts)
        }
    }
  }
}
