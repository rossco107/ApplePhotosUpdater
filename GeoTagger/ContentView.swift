//
//  ContentView.swift
//  GeoTagger
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Apple Photos Updater")
          .font(.title)
          .fontWeight(.semibold)

        Text("Photo location and library maintenance")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      GPXSection()
      JPEGSection()

      Spacer(minLength: 0)
    }
    .padding(24)
    .frame(minWidth: 760, minHeight: 600)
  }
}

#Preview {
  ContentView()
}
