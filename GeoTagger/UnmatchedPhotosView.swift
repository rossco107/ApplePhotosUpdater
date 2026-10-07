//
//  UnmatchedPhotosView.swift
//  GeoTagger
//

import SwiftUI

struct UnmatchedPhotosView: View {
  let photos: [UnmatchedPhoto]

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Unmatched Photos")
          .font(.title)

        Spacer()

        Button("Done") {
          dismiss()
        }
      }

      Text(
        "\(photos.count) photo\(photos.count == 1 ? "" : "s") could not be matched to the GPX track."
      )
      .foregroundStyle(.secondary)

      List(photos) { photo in
        HStack(spacing: 14) {
          PhotoThumbnail(asset: photo.asset)

          VStack(alignment: .leading, spacing: 5) {
            Text(dateAndTime(photo.date))
              .fontWeight(.medium)

            Text("No GPX match")
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(.vertical, 4)
      }
    }
    .padding(24)
    .frame(width: 650, height: 550)
  }

  private func dateAndTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}
