//
//  PhotoFilenameIndex.swift
//  GeoTagger
//

import Foundation
import Photos
import Combine

@MainActor
final class PhotoFilenameIndex: ObservableObject {
  @Published private(set) var isBuilding = false
  @Published private(set) var indexedAssetCount = 0

  private var assetsByFilename: [String: [String]] = [:]
  private var isBuilt = false

  func assets(named filename: String) async -> [PHAsset] {
    if !isBuilt {
      await rebuild()
    }

    let identifiers =
      assetsByFilename[filename.lowercased()] ?? []

    return identifiers.compactMap { identifier in
      PHAsset.fetchAssets(
        withLocalIdentifiers: [identifier],
        options: nil
      ).firstObject
    }
  }

  func rebuild() async {
    guard !isBuilding else {
      return
    }

    isBuilding = true

    let index = await Task.detached(
      priority: .userInitiated
    ) {
      Self.buildIndex()
    }.value

    assetsByFilename = index.assetsByFilename
    indexedAssetCount = index.assetCount
    isBuilt = true
    isBuilding = false
  }

  func add(_ asset: PHAsset, filename: String) {
    let key = filename.lowercased()
    var identifiers = assetsByFilename[key] ?? []

    if !identifiers.contains(asset.localIdentifier) {
      identifiers.append(asset.localIdentifier)
      assetsByFilename[key] = identifiers
      indexedAssetCount += 1
    }
  }

  func replace(
    _ oldAsset: PHAsset,
    with newAsset: PHAsset,
    filename: String
  ) {
    let key = filename.lowercased()
    var identifiers = assetsByFilename[key] ?? []

    identifiers.removeAll {
      $0 == oldAsset.localIdentifier
    }

    if !identifiers.contains(newAsset.localIdentifier) {
      identifiers.append(newAsset.localIdentifier)
    }

    assetsByFilename[key] = identifiers
  }

  private nonisolated static func buildIndex()
    -> (
      assetsByFilename: [String: [String]],
      assetCount: Int
    ) {
    let assets =
      PHAsset.fetchAssets(
        with: .image,
        options: nil
      )

    var index: [String: [String]] = [:]

    assets.enumerateObjects { asset, _, _ in
      let resources =
        PHAssetResource.assetResources(
          for: asset
        )

      let filenames =
        Set(resources.map(\.originalFilename))

      for filename in filenames {
        index[filename.lowercased(), default: []]
          .append(asset.localIdentifier)
      }
    }

    return (
      assetsByFilename: index,
      assetCount: assets.count
    )
  }
}
