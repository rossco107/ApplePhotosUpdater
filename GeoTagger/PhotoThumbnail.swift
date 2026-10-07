//
//  PhotoThumbnail.swift
//  GeoTagger
//

import SwiftUI
import Photos

struct PhotoThumbnail: View {
  let asset: PHAsset
  var width: CGFloat = 72
  var height: CGFloat = 72

  @State private var image: NSImage?

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Rectangle()
          .fill(.quaternary)
      }
    }
    .frame(width: width, height: height)
    .clipShape(
      RoundedRectangle(cornerRadius: 6)
    )
    .task(id: asset.localIdentifier) {
      loadThumbnail()
    }
  }

  private func loadThumbnail() {
    let options = PHImageRequestOptions()
    options.deliveryMode = .opportunistic
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: NSSize(
        width: width * 2,
        height: height * 2
      ),
      contentMode: .aspectFill,
      options: options
    ) { result, _ in
      if let result {
        DispatchQueue.main.async {
          image = result
        }
      }
    }
  }
}
