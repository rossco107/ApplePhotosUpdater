//
//  GPXSection.swift
//  GeoTagger
//

import SwiftUI
import UniformTypeIdentifiers
import Photos
import CoreLocation
import MapKit

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

struct GPXSection: View {
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
  private let recentGPXPathsKey = "recentGPXPaths"
  private let recentGPXBookmarksKey = "recentGPXBookmarks"

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Geotagging", systemImage: "location")
        .font(.title2)
        .fontWeight(.semibold)

      HStack(alignment: .top, spacing: 32) {
        VStack(alignment: .leading, spacing: 12) {
          Text("GPX track")
            .font(.headline)

          if let gpxFile {
            VStack(alignment: .leading, spacing: 4) {
              Text(gpxFile.lastPathComponent)
                .fontWeight(.medium)

              Text("\(gpxPoints.count) track points")
                .font(.subheadline)
                .foregroundStyle(.secondary)

              if let startDate, let endDate {
                Text(
                  "\(dateAndTime(startDate)) – \(dateAndTime(endDate))"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
              }
            }
          } else {
            Text("No track selected")
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 10) {
            Button {
              showingImporter = true
            } label: {
              Label("Choose GPX…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)

            Button {
              findPhotos()
            } label: {
              Label("Find Photos", systemImage: "photo.badge.magnifyingglass")
            }
            .disabled(gpxPoints.isEmpty)

            Button {
              showingDiagnostics = true
            } label: {
              Label("Diagnostics", systemImage: "chart.bar")
            }
            .disabled(diagnostics.isEmpty)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if !recentGPXFiles.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
              .font(.headline)

            ForEach(recentGPXFiles, id: \.self) { url in
              Button {
                loadGPX(url)
              } label: {
                HStack(spacing: 7) {
                  Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)

                  Text(displayPath(for: url))
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
              .help(url.path)
            }
          }
          .frame(width: 300, alignment: .leading)
        }
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

            LocationMapSnapshot(
              latitude: match.latitude,
              longitude: match.longitude
            )
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
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.background.secondary)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(.separator.opacity(0.45), lineWidth: 1)
    }
    .onAppear {
      restoreRecentGPXFiles()
    }
    .fileImporter(
      isPresented: $showingImporter,
      allowedContentTypes: [.xml],
      allowsMultipleSelection: false
    ) { result in
      loadGPX(result)
    }
    .sheet(isPresented: $showingUnmatched) {
      UnmatchedPhotosView(photos: unmatchedPhotos)
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
    let hasSecurityScope =
      url.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

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

    saveRecentGPXFiles()
  }

  private func saveRecentGPXFiles() {
    let paths = recentGPXFiles.map(\.path)
    UserDefaults.standard.set(
      paths,
      forKey: recentGPXPathsKey
    )

    var bookmarks = UserDefaults.standard.dictionary(
      forKey: recentGPXBookmarksKey
    ) as? [String: Data] ?? [:]

    for url in recentGPXFiles {
      let hasSecurityScope =
        url.startAccessingSecurityScopedResource()

      defer {
        if hasSecurityScope {
          url.stopAccessingSecurityScopedResource()
        }
      }

      do {
        bookmarks[url.path] = try url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
      } catch {
        status =
          "Could not remember access to \(url.lastPathComponent): " +
          error.localizedDescription
      }
    }

    UserDefaults.standard.set(
      bookmarks,
      forKey: recentGPXBookmarksKey
    )
  }

  private func restoreRecentGPXFiles() {
    guard recentGPXFiles.isEmpty else {
      return
    }

    let paths = UserDefaults.standard.stringArray(
      forKey: recentGPXPathsKey
    ) ?? []

    let bookmarks = UserDefaults.standard.dictionary(
      forKey: recentGPXBookmarksKey
    ) as? [String: Data] ?? [:]

    recentGPXFiles = paths.prefix(3).map { path in
      guard let bookmark = bookmarks[path] else {
        return URL(fileURLWithPath: path)
      }

      do {
        var isStale = false
        let url = try URL(
          resolvingBookmarkData: bookmark,
          options: .withSecurityScope,
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )

        let hasSecurityScope =
          url.startAccessingSecurityScopedResource()

        if isStale {
          refreshBookmark(for: url)
        }

        if hasSecurityScope {
          url.stopAccessingSecurityScopedResource()
        }

        return url
      } catch {
        return URL(fileURLWithPath: path)
      }
    }
  }

  private func refreshBookmark(for url: URL) {
    let hasSecurityScope =
      url.startAccessingSecurityScopedResource()

    defer {
      if hasSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      var bookmarks = UserDefaults.standard.dictionary(
        forKey: recentGPXBookmarksKey
      ) as? [String: Data] ?? [:]

      bookmarks[url.path] = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      UserDefaults.standard.set(
        bookmarks,
        forKey: recentGPXBookmarksKey
      )
    } catch {
      status =
        "Could not refresh access to \(url.lastPathComponent): " +
        error.localizedDescription
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

      let day = calendar.startOfDay(for: date)
      var counts = countsByDay[day] ?? Counts()
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

  private func displayPath(for url: URL) -> String {
    let folder = url.deletingLastPathComponent().lastPathComponent
    return folder + "/" + url.lastPathComponent
  }

  private func dateAndTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}


private struct LocationMapSnapshot: View {
  let latitude: Double
  let longitude: Double

  @State private var image: NSImage?

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ProgressView()
      }
    }
    .frame(width: 180, height: 120)
    .background(.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .task(id: snapshotID) {
      image = await makeSnapshot()
    }
  }

  private var snapshotID: String {
    String(format: "%.6f,%.6f", latitude, longitude)
  }

  private func makeSnapshot() async -> NSImage? {
    let coordinate = CLLocationCoordinate2D(
      latitude: latitude,
      longitude: longitude
    )

    let options = MKMapSnapshotter.Options()
    options.region = MKCoordinateRegion(
      center: coordinate,
      latitudinalMeters: 700,
      longitudinalMeters: 700
    )
    options.size = CGSize(width: 180, height: 120)
    options.mapType = .standard

    do {
      let snapshot = try await MKMapSnapshotter(
        options: options
      ).start()

      let image = snapshot.image.copy() as! NSImage
      let point = snapshot.point(for: coordinate)

      image.lockFocus()

      let marker = NSBezierPath(
        ovalIn: NSRect(
          x: point.x - 5,
          y: point.y - 5,
          width: 10,
          height: 10
        )
      )
      NSColor.systemRed.setFill()
      marker.fill()

      image.unlockFocus()
      return image
    } catch {
      return nil
    }
  }
}
