//
//  NSPasteboard+Convenience.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 2/12/23.
//

import AppKit

extension NSPasteboard {
  func add(string: String = "", image: NSImage? = nil) {
    self.clearContents()

    // Put the image on the clipboard first, then the text.
    if let image {
      self.writeObjects([image])
    }
    if !string.isEmpty {
      self.setString(string, forType: .string)
    }
  }
}
