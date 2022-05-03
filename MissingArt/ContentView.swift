//
//  ContentView.swift
//  MissingArt
//
//  Created by Greg Bolsinga on 4/7/22.
//

import MissingArtwork
import SwiftUI

struct ContentView: View {
  let model: Model

  var body: some View {
    DescriptionList(missingArtworks: model.missingArtworks)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    let model = Model(missingArtworks: [
      MissingArtwork.ArtistAlbum("The Stooges", "Fun House"),
      .CompilationAlbum("Beleza Tropical: Brazil Classics 1"),
    ])
    ContentView(model: model)
  }
}
