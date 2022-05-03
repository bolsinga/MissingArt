//
//  DeveloperToken.swift
//
//
//  Created by Greg Bolsinga on 4/24/22.
//

import SwiftUI
import UniformTypeIdentifiers

struct DeveloperToken: View {
  @State private var parts: TokenParts

  @State private var showFileImporter = false

  public init(parts: TokenParts) {
    self.parts = parts
  }

  public var body: some View {
    Form {
      TextField(
        text: Binding<String>(
          get: { parts.key ?? "" },
          set: {
            parts.key = $0
            parts.validate()
          }),
        prompt: Text("Required")
      ) {
        Text("Apple Developer Key ID")
      }
      .disableAutocorrection(true)

      TextField(
        text: Binding<String>(
          get: { parts.team ?? "" },
          set: {
            parts.team = $0
            parts.validate()

          }), prompt: Text("Required")
      ) {
        Text("Apple Developer Team ID")
      }
      .disableAutocorrection(true)

      Section(header: Text("p8 File")) {
        Button(
          action: {
            showFileImporter.toggle()
          },
          label: {
            let hasChosenFile = parts.isP8Valid
            Label(
              hasChosenFile ? "Update" : "Choose",
              systemImage: hasChosenFile ? "doc.badge.gearshape" : "doc.badge.plus")
          })
      }
    }
    .frame(width: 300)
    .navigationTitle("Missing Artwork Token")
    .padding(80)
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: [UTType(filenameExtension: "p8", conformingTo: .data)!]
    ) { result in
      do {
        parts.p8 = try result.get()
        parts.validate()
      } catch {
        fatalError("Unable to read p8 file")
      }
    }
  }
}

struct DeveloperToken_Previews: PreviewProvider {
  static var previews: some View {
    DeveloperToken(parts: TokenParts())
  }
}
