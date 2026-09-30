//
//  ContentView.swift
//  GeoTagger
//
//  Created by Ross Carter on 19/09/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import Photos
import CoreLocation

struct UnmatchedPhoto: Identifiable {
  let id: String
  let asset: PHAsset
  let date: Date
}

struct DayDiagnostic: Identifiable {
  let id = UUID()
  let date: Date
  let total: Int
  let geotagged: Int
  let untagged: Int
  let matched: Int
  let unmatched: Int
}

struct ContentView: View {
  @State private var gpxFile: URL?
  @State private var gpxPoints: [GPXPoint] = []
  @State private var showingImporter = false
  @State private var recentGPXFiles: [URL] = []

  @State private var startDate: Date?
  @State private var endDate: Date?

  @State private var photosInRange = 0
  @State private var alreadyGeotagged = 0
  @State private var untaggedPhotos = 0

  @State private var photoMatches: [PhotoMatch] = []
  @State private var unmatchedPhotos: [UnmatchedPhoto] = []
  @State private var diagnostics: [DayDiagnostic] = []

  @State private var showingWriteConfirmation = false
  @State private var showingUnmatched = false
  @State private var showingDiagnostics = false
  @State private var status = ""

  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Spacer()

        Text("GeoTagger")
          .font(.largeTitle)

        Spacer()
      }

      Divider()

      if let gpxFile {
        Text(gpxFile.lastPathComponent)
          .font(.headline)

        Text("\(gpxPoints.count) GPX points")
          .foregroundStyle(.secondary)

        if let startDate, let endDate {
          Text(
            "GPX: \(dateAndTime(startDate)) – \(dateAndTime(endDate))"
          )
        }
      } else {
        Text("No GPX file selected")
          .foregroundStyle(.secondary)
      }

      HStack {
        Menu("Choose GPX") {
          Button("Choose GPX…") {
            showingImporter = true
          }

          if !recentGPXFiles.isEmpty {
            Divider()

            ForEach(recentGPXFiles, id: \.self) { url in
              Button(url.lastPathComponent) {
                loadGPX(url)
              }
            }
          }
        }

        Button("Find Photos") {
          findPhotos()
        }
        .disabled(gpxPoints.isEmpty)

        Button("Diagnostics") {
          showingDiagnostics = true
        }
        .disabled(diagnostics.isEmpty)
      }

      if photosInRange > 0 {
        Divider()

        Grid(alignment: .leading, horizontalSpacing: 20) {
          GridRow {
            Text("Photos in date range:")
            Text("\(photosInRange)")
              .monospacedDigit()
          }

          GridRow {
            Text("Already geotagged:")
            Text("\(alreadyGeotagged)")
              .monospacedDigit()
          }

          GridRow {
            Text("Untagged:")
            Text("\(untaggedPhotos)")
              .monospacedDigit()
          }

          GridRow {
            Text("Matched:")
            Text("\(photoMatches.count)")
              .monospacedDigit()
          }

          GridRow {
            Text("Unmatched:")
            Text("\(unmatchedPhotos.count)")
              .monospacedDigit()
          }
        }

        if !unmatchedPhotos.isEmpty {
          Button("Show \(unmatchedPhotos.count) Unmatched") {
            showingUnmatched = true
          }
        }
      }

      if !photoMatches.isEmpty {
        Divider()

        Text("Locations to be written")
          .font(.headline)

        List(photoMatches) { match in
          HStack(spacing: 14) {
            PhotoThumbnail(asset: match.asset)

            VStack(alignment: .leading, spacing: 5) {
              Text(dateAndTime(match.date))
                .fontWeight(.medium)

              Text(
                String(
                  format: "%.6f, %.6f",
                  match.latitude,
                  match.longitude
                )
              )
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.secondary)
            }

            Spacer()
          }
          .padding(.vertical, 4)
        }
        .frame(minHeight: 300)

        HStack {
          Spacer()

          Button("Write \(photoMatches.count) Locations") {
            showingWriteConfirmation = true
          }
          .buttonStyle(.borderedProminent)
        }
      }

      if !status.isEmpty {
        Text(status)
          .foregroundStyle(.secondary)
      }
    }
    .padding(24)
    .frame(minWidth: 700, minHeight: 600)
    .fileImporter(
      isPresented: $showingImporter,
      allowedContentTypes: [.xml],
      allowsMultipleSelection: false
    ) { result in
      loadGPX(result)
    }
    .sheet(isPresented: $showingUnmatched) {
      UnmatchedPhotosView(
        photos: unmatchedPhotos
      )
    }
    .sheet(isPresented: $showingDiagnostics) {
      DiagnosticsView(
        diagnostics: diagnostics,
        firstGPXDate: gpxPoints.first?.date,
        lastGPXDate: gpxPoints.last?.date
      )
    }
    .confirmationDialog(
      "Write \(photoMatches.count) locations to Photos?",
      isPresented: $showingWriteConfirmation
    ) {
      Button("Write Locations") {
        writeLocations()
      }

      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Only photographs that currently have no location will be changed."
      )
    }
  }

  private func loadGPX(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let files):
      guard let url = files.first else {
        return
      }

      loadGPX(url)

    case .failure(let error):
      status =
        "GPX selection failed: \(error.localizedDescription)"
    }
  }

  private func loadGPX(_ url: URL) {
    do {
      let points = try GPXParser().parse(url: url)

      guard let first = points.first,
            let last = points.last else {
        status = "The GPX file contains no timed track points."
        return
      }

      gpxFile = url
      gpxPoints = points
      startDate = first.date
      endDate = last.date

      addRecentGPX(url)
      clearPhotoResults()

      status = "GPX loaded: \(points.count) points"
    } catch {
      gpxFile = nil
      gpxPoints = []
      startDate = nil
      endDate = nil

      clearPhotoResults()

      status =
        "GPX could not be read: \(error.localizedDescription)"
    }
  }

  private func addRecentGPX(_ url: URL) {
    recentGPXFiles.removeAll { $0 == url }
    recentGPXFiles.insert(url, at: 0)

    if recentGPXFiles.count > 3 {
      recentGPXFiles.removeLast()
    }
  }

  private func findPhotos() {
    guard let first = gpxPoints.first,
          let last = gpxPoints.last else {
      return
    }

    PHPhotoLibrary.requestAuthorization(for: .readWrite) { authStatus in
      DispatchQueue.main.async {
        guard authStatus == .authorized ||
              authStatus == .limited else {
          status = "Photos access is required."
          return
        }

        searchPhotos(
          firstGPXDate: first.date,
          lastGPXDate: last.date
        )
      }
    }
  }

  private func searchPhotos(
    firstGPXDate: Date,
    lastGPXDate: Date
  ) {
    clearPhotoResults()

    let rangeStart =
      calendar.startOfDay(for: firstGPXDate)

    guard let dayAfterEnd = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: lastGPXDate)
    ) else {
      status = "Could not calculate the photo date range."
      return
    }

    let options = PHFetchOptions()

    options.predicate = NSPredicate(
      format: "creationDate >= %@ AND creationDate < %@",
      rangeStart as NSDate,
      dayAfterEnd as NSDate
    )

    options.sortDescriptors = [
      NSSortDescriptor(
        key: "creationDate",
        ascending: true
      )
    ]

    let assets = PHAsset.fetchAssets(
      with: .image,
      options: options
    )

    photosInRange = assets.count

    let matcher = GPXMatcher(points: gpxPoints)

    struct Counts {
      var total = 0
      var geotagged = 0
      var untagged = 0
      var matched = 0
      var unmatched = 0
    }

    var countsByDay: [Date: Counts] = [:]

    assets.enumerateObjects { asset, _, _ in
      guard let date = asset.creationDate else {
        return
      }

      let day =
        calendar.startOfDay(for: date)

      var counts =
        countsByDay[day] ?? Counts()

      counts.total += 1

      if asset.location != nil {
        alreadyGeotagged += 1
        counts.geotagged += 1

        countsByDay[day] = counts
        return
      }

      untaggedPhotos += 1
      counts.untagged += 1

      if let match = matcher.findPosition(for: date) {
        counts.matched += 1

        photoMatches.append(
          PhotoMatch(
            id: asset.localIdentifier,
            asset: asset,
            date: date,
            latitude: match.latitude,
            longitude: match.longitude
          )
        )
      } else {
        counts.unmatched += 1

        unmatchedPhotos.append(
          UnmatchedPhoto(
            id: asset.localIdentifier,
            asset: asset,
            date: date
          )
        )
      }

      countsByDay[day] = counts
    }

    diagnostics =
      countsByDay
        .keys
        .sorted()
        .map { day in
          let counts = countsByDay[day]!

          return DayDiagnostic(
            date: day,
            total: counts.total,
            geotagged: counts.geotagged,
            untagged: counts.untagged,
            matched: counts.matched,
            unmatched: counts.unmatched
          )
        }

    if untaggedPhotos == 0 {
      status =
        "All photos in this date range already have locations."
    } else if photoMatches.isEmpty {
      status =
        "No untagged photos could be matched to this GPX track."
    } else {
      status =
        "\(photoMatches.count) untagged photo(s) ready to geotag."
    }
  }

  private func writeLocations() {
    let matches = photoMatches

    guard !matches.isEmpty else {
      return
    }

    PHPhotoLibrary.shared().performChanges {
      for match in matches {
        let request =
          PHAssetChangeRequest(for: match.asset)

        request.location = CLLocation(
          latitude: match.latitude,
          longitude: match.longitude
        )
      }
    } completionHandler: { success, error in
      DispatchQueue.main.async {
        if success {
          status =
            "Finished. Locations written: \(matches.count)"

          if let first = gpxPoints.first,
             let last = gpxPoints.last {
            searchPhotos(
              firstGPXDate: first.date,
              lastGPXDate: last.date
            )
          }
        } else {
          status =
            "Write failed: " +
            (error?.localizedDescription ?? "Unknown error")
        }
      }
    }
  }

  private func clearPhotoResults() {
    photosInRange = 0
    alreadyGeotagged = 0
    untaggedPhotos = 0
    photoMatches = []
    unmatchedPhotos = []
    diagnostics = []
  }

  private func dateAndTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}

struct DiagnosticsView: View {
  let diagnostics: [DayDiagnostic]
  let firstGPXDate: Date?
  let lastGPXDate: Date?

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text("Diagnostics")
          .font(.title)

        Spacer()

        Button("Done") {
          dismiss()
        }
      }

      if let firstGPXDate,
         let lastGPXDate {
        VStack(alignment: .leading, spacing: 4) {
          Text("Actual GPX coverage")
            .font(.headline)

          Text(
            "\(dateAndTime(firstGPXDate)) – \(dateAndTime(lastGPXDate))"
          )
          .monospacedDigit()
        }
      }

      Divider()

      Grid(
        alignment: .leading,
        horizontalSpacing: 24,
        verticalSpacing: 8
      ) {
        GridRow {
          Text("Date")
          Text("Total")
          Text("Tagged")
          Text("Untagged")
          Text("Matched")
          Text("Unmatched")
        }
        .fontWeight(.semibold)

        Divider()
          .gridCellColumns(6)

        ForEach(diagnostics) { item in
          GridRow {
            Text(dateOnly(item.date))

            Text("\(item.total)")
              .monospacedDigit()

            Text("\(item.geotagged)")
              .monospacedDigit()

            Text("\(item.untagged)")
              .monospacedDigit()

            Text("\(item.matched)")
              .monospacedDigit()

            Text("\(item.unmatched)")
              .monospacedDigit()
          }
        }

        Divider()
          .gridCellColumns(6)

        GridRow {
          Text("Total")
            .fontWeight(.semibold)

          Text(
            "\(diagnostics.reduce(0) { $0 + $1.total })"
          )

          Text(
            "\(diagnostics.reduce(0) { $0 + $1.geotagged })"
          )

          Text(
            "\(diagnostics.reduce(0) { $0 + $1.untagged })"
          )

          Text(
            "\(diagnostics.reduce(0) { $0 + $1.matched })"
          )

          Text(
            "\(diagnostics.reduce(0) { $0 + $1.unmatched })"
          )
        }
        .fontWeight(.semibold)
        .monospacedDigit()
      }

      Spacer()
    }
    .padding(24)
    .frame(width: 720, height: 400)
  }

  private func dateOnly(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  private func dateAndTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}

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

struct PhotoThumbnail: View {
  let asset: PHAsset

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
    .frame(width: 72, height: 72)
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
        width: 144,
        height: 144
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

#Preview {
  ContentView()
}
