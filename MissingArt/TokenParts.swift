//
//  TokenParts.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 5/2/22.
//

import CupertinoJWT
import Foundation
import SwiftUI

class TokenParts: ObservableObject {
  @AppStorage("dev.key") var key: String?
  @AppStorage("dev.team") var team: String?
  @AppStorage("dev.p8") var p8: String?

  @Published var token: String?

  @Published var requiresTokenRefresh: Bool

  init() {
    self.requiresTokenRefresh = true
    validate()
  }

  func save(p8URL: URL) {
    if let p8String = try? String(contentsOf: p8URL) {
      p8 = p8String
      validate()
    }
  }

  var hasP8Data: Bool {
    return p8 != nil
  }

  func validate() {
    if token != nil {
      self.requiresTokenRefresh = false
    } else {
      if let key = key, let team = team, let p8 = p8 {
        if let token = generateToken(key: key, team: team, p8: p8) {
          self.token = token
          self.requiresTokenRefresh = false
        }
      }
    }
  }

  private func generateToken(key: String, team: String, p8: String) -> String? {
    let token = try? JWT(keyID: key, teamID: team, issueDate: Date(), expireDuration: 60 * 60)
      .sign(with: p8)
    return token
  }
}
