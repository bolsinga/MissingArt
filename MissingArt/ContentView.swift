//
//  ContentView.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

struct ContentView: View {
  let token: String

  var body: some View {
    DescriptionList(token: token)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(token: "")
      .environmentObject(Model.preview)
  }
}
