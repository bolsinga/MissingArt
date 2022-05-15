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
  @Published var token: String?

  var p8: URL?

  @Published var invalid: Bool

  init() {
    self.invalid = true
    validate()
  }

  var isP8Valid: Bool {
    if let p8 = p8 {
      return p8.isFileURL && FileManager.default.fileExists(atPath: p8.path)
    }
    return false
  }

  func validate() {
    if token != nil {
      self.invalid = false
    } else {
      if let key = key, let team = team, isP8Valid, let p8 = p8 {
        if let token = generateToken(key: key, team: team, p8: p8) {
          self.token = token
          self.invalid = false
        }
      }
    }
  }

  private func generateToken(key: String, team: String, p8: URL) -> String? {
    if let signingData = try? String(contentsOf: p8) {
      let token = try? JWT(keyID: key, teamID: team, issueDate: Date(), expireDuration: 60 * 60)
        .sign(with: signingData)
      return token
    }
    return nil
  }
}
