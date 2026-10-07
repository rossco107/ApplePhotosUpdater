//
//  JPEGSection.swift
//  GeoTagger
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Photos
import ImageIO

private enum JPEGBatchResult {
  case added
  case replaced(Int)
  case skipped
  case failed
}

private struct JPEGBatchItem: Identifiable {
  let id = UUID()
  let url: URL
  let image: NSImage?
  let width: Int?
  let height: Int?
  let fileSize: Int64?
  var matches: [PHAsset] = []
  var albums: [PHAssetCollection] = []
  var include = true
  var result: JPEGBatchResult?

  var actionTitle: String {
    switch matches.count {
    case 0: return "Add"
    case 1: return "Replace"
    default: return "Replace all"
    }
  }
}

struct JPEGSection: View {
  @StateObject private var photoIndex =
    PhotoFilenameIndex()

  @State private var items: [JPEGBatchItem] = []
  @State private var hasSearchedPhotos = false
  @State private var isProcessing = false
  @State private var status = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Add / Replace JPEG", systemImage: "photo.on.rectangle.angled")
        .font(.title2)
        .fontWeight(.semibold)

      if items.isEmpty {
        Text("Compare edited JPEGs with the versions already in Photos.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack {
        Button {
          selectJPEGs()
        } label: {
          Label("Select JPEGs or Folder…", systemImage: "folder")
        }
        .buttonStyle(.borderedProminent)

        if !items.isEmpty {
          Button("Check Photos") {
            checkPhotos()
          }
          .buttonStyle(.borderedProminent)
          .disabled(photoIndex.isBuilding || isProcessing)

          Button("Change Ticked") {
            changeTicked()
          }
          .buttonStyle(.borderedProminent)
          .disabled(
            !hasSearchedPhotos ||
            isProcessing ||
            !items.contains {
              $0.include && $0.result == nil
            }
          )
        }
      }

      if photoIndex.isBuilding {
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)

          Text("Indexing Photos…")
            .foregroundStyle(.secondary)
        }
      }

      if isProcessing {
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)

          Text("Updating Photos…")
            .foregroundStyle(.secondary)
        }
      }

      if !items.isEmpty {
        VStack(spacing: 0) {
          HStack(alignment: .firstTextBaseline) {
            Text("Source")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text("Photos")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text("Add / Replace")
              .font(.headline)
              .frame(width: 150, alignment: .leading)
          }
          .padding(.bottom, 8)

          Divider()

          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach($items) { $item in
                JPEGBatchRow(
                  item: $item,
                  hasSearchedPhotos: hasSearchedPhotos
                )

                Divider()
              }
            }
          }
          .frame(maxHeight: 500)

          if hasSearchedPhotos {
            Divider()

            HStack {
              Button("Change Ticked") {
                changeTicked()
              }
              .buttonStyle(.borderedProminent)
              .disabled(
                isProcessing ||
                !items.contains {
                  $0.include && $0.result == nil
                }
              )

              Spacer()
            }
            .padding(.top, 10)
          }
        }
      }

      if !status.isEmpty {
        Divider()
          .padding(.top, 4)

        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 2)
      }
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.background.secondary)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(.separator.opacity(0.45), lineWidth: 1)
    }
  }

  private func selectJPEGs() {
    let panel = NSOpenPanel()
    panel.title = "Select JPEGs or Folders"
    panel.prompt = "Select"
    panel.allowedContentTypes = [.jpeg]
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.resolvesAliases = true

    guard panel.runModal() == .OK else {
      return
    }

    resetSelection()

    var urls: [URL] = []

    for url in panel.urls {
      if url.hasDirectoryPath {
        urls.append(contentsOf: JPEGFiles(in: url))
      } else if isJPEG(url) {
        urls.append(url)
      }
    }

    let uniqueURLs = Array(
      Dictionary(
        urls.map { ($0.path, $0) },
        uniquingKeysWith: { first, _ in first }
      ).values
    )
    .sorted {
      $0.lastPathComponent.localizedStandardCompare(
        $1.lastPathComponent
      ) == .orderedAscending
    }

    loadItems(from: uniqueURLs)
  }

  private func JPEGFiles(in folder: URL) -> [URL] {
    let accessing =
      folder.startAccessingSecurityScopedResource()

    defer {
      if accessing {
        folder.stopAccessingSecurityScopedResource()
      }
    }

    do {
      return try FileManager.default.contentsOfDirectory(
        at: folder,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      .filter(isJPEG)
    } catch {
      status =
        "Folder could not be read: \(error.localizedDescription)"
      return []
    }
  }

  private func loadItems(from urls: [URL]) {
    items = urls
      .filter(isJPEG)
      .map(makeItem)
    hasSearchedPhotos = false
    status = items.isEmpty
      ? "No JPEG files selected."
      : "\(items.count) JPEG file(s) selected."
  }

  private func makeItem(_ url: URL) -> JPEGBatchItem {
    let accessing =
      url.startAccessingSecurityScopedResource()

    defer {
      if accessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let image = NSImage(contentsOf: url)
    var width: Int?
    var height: Int?

    if let source =
      CGImageSourceCreateWithURL(
        url as CFURL,
        nil
      ),
       let properties =
      CGImageSourceCopyPropertiesAtIndex(
        source,
        0,
        nil
      ) as? [CFString: Any] {
      width =
        properties[kCGImagePropertyPixelWidth] as? Int
      height =
        properties[kCGImagePropertyPixelHeight] as? Int
    }

    let values =
      try? url.resourceValues(
        forKeys: [.fileSizeKey]
      )

    return JPEGBatchItem(
      url: url,
      image: image,
      width: width,
      height: height,
      fileSize: values?.fileSize.map(Int64.init)
    )
  }

  private func isJPEG(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return ext == "jpg" || ext == "jpeg"
  }

  private func checkPhotos() {
    guard !items.isEmpty else {
      return
    }

    PHPhotoLibrary.requestAuthorization(
      for: .readWrite
    ) { authStatus in
      DispatchQueue.main.async {
        guard authStatus == .authorized ||
              authStatus == .limited else {
          status = "Photos access is required."
          return
        }

        Task {
          await findExistingJPEGs()
        }
      }
    }
  }

  @MainActor
  private func findExistingJPEGs() async {
    status = photoIndex.isBuilding
      ? "Searching Photos…"
      : ""

    for index in items.indices {
      items[index].matches =
        await photoIndex.assets(
          named: items[index].url.lastPathComponent
        )
      items[index].albums =
        albumsContaining(items[index].matches)
    }

    hasSearchedPhotos = true
    status = "\(items.count) JPEG file(s) checked."
  }

  private func albumsContaining(
    _ assets: [PHAsset]
  ) -> [PHAssetCollection] {
    var albums: [String: PHAssetCollection] = [:]

    for asset in assets {
      let collections =
        PHAssetCollection.fetchAssetCollectionsContaining(
          asset,
          with: .album,
          options: nil
        )

      collections.enumerateObjects { collection, _, _ in
        albums[collection.localIdentifier] = collection
      }
    }

    return Array(albums.values)
  }

  private func changeTicked() {
    let selectedIndices = items.indices.filter {
      items[$0].include &&
      items[$0].result == nil
    }

    guard !selectedIndices.isEmpty else {
      return
    }

    isProcessing = true

    let selectedItems =
      selectedIndices.map { items[$0] }

    var placeholders:
      [UUID: PHObjectPlaceholder] = [:]

    PHPhotoLibrary.shared().performChanges {
      let assetsToDelete =
        selectedItems.flatMap(\.matches)

      if !assetsToDelete.isEmpty {
        PHAssetChangeRequest.deleteAssets(
          assetsToDelete as NSArray
        )
      }

      for item in selectedItems {
        let request =
          PHAssetCreationRequest.forAsset()

        if let oldAsset = item.matches.first {
          request.creationDate =
            oldAsset.creationDate
          request.location =
            oldAsset.location
          request.isFavorite =
            oldAsset.isFavorite
          request.isHidden =
            oldAsset.isHidden
        }

        request.addResource(
          with: .photo,
          fileURL: item.url,
          options: nil
        )

        if let placeholder =
          request.placeholderForCreatedAsset {
          placeholders[item.id] = placeholder

          for album in item.albums {
            let albumRequest =
              PHAssetCollectionChangeRequest(
                for: album
              )
            albumRequest?.addAssets(
              [placeholder] as NSArray
            )
          }
        }
      }
    } completionHandler: { success, error in
      DispatchQueue.main.async {
        guard success else {
          for index in selectedIndices {
            self.items[index].result = .failed
          }

          self.status =
            error?.localizedDescription ??
            "Batch update failed."
          self.isProcessing = false
          return
        }

        var completed = 0

        for index in selectedIndices {
          let oldAssets =
            self.items[index].matches

          guard let placeholder =
                  placeholders[self.items[index].id],
                let newAsset =
                  PHAsset.fetchAssets(
                    withLocalIdentifiers: [
                      placeholder.localIdentifier
                    ],
                    options: nil
                  ).firstObject else {
            self.items[index].result = .failed
            continue
          }

          self.items[index].matches = [newAsset]

          if oldAssets.isEmpty {
            self.photoIndex.add(
              newAsset,
              filename:
                self.items[index].url.lastPathComponent
            )
            self.items[index].result = .added
          } else {
            for oldAsset in oldAssets {
              self.photoIndex.replace(
                oldAsset,
                with: newAsset,
                filename:
                  self.items[index].url.lastPathComponent
              )
            }

            self.items[index].result =
              .replaced(oldAssets.count)
          }

          completed += 1
        }

        self.status =
          "\(completed) file(s) updated."
        self.isProcessing = false
      }
    }
  }

  private func resetSelection() {
    items = []
    hasSearchedPhotos = false
    isProcessing = false
    status = ""
  }
}

private struct JPEGPhotosThumbnail: View {
  let asset: PHAsset

  @State private var image: NSImage?

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Rectangle()
          .fill(.quaternary)
      }
    }
    .frame(width: 160, height: 120)
    .background(.quaternary)
    .clipShape(
      RoundedRectangle(cornerRadius: 6)
    )
    .task(id: asset.localIdentifier) {
      loadThumbnail()
    }
  }

  private func loadThumbnail() {
    image = nil

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    options.isNetworkAccessAllowed = true

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: NSSize(
        width: 320,
        height: 240
      ),
      contentMode: .aspectFit,
      options: options
    ) { result, _ in
      guard let result else {
        return
      }

      DispatchQueue.main.async {
        image = result
      }
    }
  }
}

private struct JPEGBatchRow: View {
  @Binding var item: JPEGBatchItem
  let hasSearchedPhotos: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 24) {
      sourceColumn
        .frame(maxWidth: .infinity, alignment: .leading)

      photosColumn
        .frame(maxWidth: .infinity, alignment: .leading)

      actionColumn
        .frame(width: 150, alignment: .leading)
    }
    .padding(.vertical, 6)
    .opacity(rowOpacity)
  }

  private var rowOpacity: Double {
    switch item.result {
    case .added, .replaced, .skipped:
      return 0.7
    case .failed, nil:
      return 1.0
    }
  }

  private var sourceColumn: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let image = item.image {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(width: 160, height: 120)
          .background(.quaternary)
          .clipShape(
            RoundedRectangle(cornerRadius: 6)
          )
      }

      Text(item.url.lastPathComponent)
        .fontWeight(.medium)

      if let width = item.width,
         let height = item.height {
        Text("\(width) × \(height)")
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }

      if let fileSize = item.fileSize {
        Text(
          ByteCountFormatter.string(
            fromByteCount: fileSize,
            countStyle: .file
          )
        )
        .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var photosColumn: some View {
    if !hasSearchedPhotos {
      Text("Not checked")
        .foregroundStyle(.secondary)
    } else if let asset = item.matches.first {
      VStack(alignment: .leading, spacing: 6) {
        JPEGPhotosThumbnail(
          asset: asset
        )

        if item.matches.count > 1 {
          Text("Multiple matches (\(item.matches.count))")
            .fontWeight(.semibold)
        }

        Text(
          "\(asset.pixelWidth) × \(asset.pixelHeight)"
        )
        .monospacedDigit()
        .foregroundStyle(.secondary)

        Text(
          "Photo date: " +
          optionalDateAndTime(asset.creationDate)
        )
        .foregroundStyle(.secondary)

        Text(
          "Date added: " +
          optionalDateAndTime(asset.addedDate)
        )
        .foregroundStyle(.secondary)

        Text(
          "Location: " +
          (asset.location == nil ? "None" : "Yes")
        )
        .foregroundStyle(.secondary)
      }
    } else {
      Text("Not found")
        .fontWeight(.medium)
    }
  }

  @ViewBuilder
  private var actionColumn: some View {
    if hasSearchedPhotos {
      if let result = item.result {
        Text(resultText(result))
          .fontWeight(.semibold)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text(item.actionTitle)
            .fontWeight(.medium)

          Toggle("Change", isOn: $item.include)
            .toggleStyle(.checkbox)
        }
      }
    }
  }

  private func resultText(
    _ result: JPEGBatchResult
  ) -> String {
    switch result {
    case .added:
      return "Added ✓"
    case .replaced(let count):
      return count == 1
        ? "Replaced ✓"
        : "Replaced \(count) ✓"
    case .skipped:
      return "Skipped"
    case .failed:
      return "Failed"
    }
  }

  private func optionalDateAndTime(
    _ date: Date?
  ) -> String {
    guard let date else {
      return "Unknown"
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}
