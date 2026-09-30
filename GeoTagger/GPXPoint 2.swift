//
//  GPXPoint 2.swift
//  GeoTagger
//
//  Created by Ross Carter on 19/09/2026.
//


import Foundation

struct GPXPoint {
  let date: Date
  let latitude: Double
  let longitude: Double
}

final class GPXParser: NSObject, XMLParserDelegate {
  private var points: [GPXPoint] = []
  private var latitude: Double?
  private var longitude: Double?
  private var timeText = ""
  private var readingTime = false

  func parse(url: URL) throws -> [GPXPoint] {
    points = []

    guard url.startAccessingSecurityScopedResource() else {
      throw GPXError.cannotAccessFile
    }
    defer { url.stopAccessingSecurityScopedResource() }

    guard let parser = XMLParser(contentsOf: url) else {
      throw GPXError.cannotReadFile
    }

    parser.delegate = self

    guard parser.parse() else {
      throw parser.parserError ?? GPXError.invalidGPX
    }

    return points.sorted { $0.date < $1.date }
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    if elementName == "trkpt" {
      latitude = Double(attributeDict["lat"] ?? "")
      longitude = Double(attributeDict["lon"] ?? "")
    }

    if elementName == "time" {
      timeText = ""
      readingTime = true
    }
  }

  func parser(
    _ parser: XMLParser,
    foundCharacters string: String
  ) {
    if readingTime {
      timeText += string
    }
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "time" {
      readingTime = false
    }

    if elementName == "trkpt",
       let latitude,
       let longitude {
      let formatter = ISO8601DateFormatter()

      if let date = formatter.date(from: timeText) {
        points.append(
          GPXPoint(
            date: date,
            latitude: latitude,
            longitude: longitude
          )
        )
      }

      self.latitude = nil
      self.longitude = nil
      timeText = ""
    }
  }
}

enum GPXError: Error {
  case cannotAccessFile
  case cannotReadFile
  case invalidGPX
}