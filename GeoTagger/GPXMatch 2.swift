//
//  GPXMatch 2.swift
//  GeoTagger
//
//  Created by Ross Carter on 19/09/2026.
//


import Foundation

struct GPXMatch {
  let latitude: Double
  let longitude: Double
}

final class GPXMatcher {
  private let points: [GPXPoint]

  init(points: [GPXPoint]) {
    self.points = points
  }

  func findPosition(for date: Date) -> GPXMatch? {
    guard !points.isEmpty else { return nil }

    let target = date.timeIntervalSince1970

    guard target >= points[0].date.timeIntervalSince1970,
          target <= points[points.count - 1].date.timeIntervalSince1970 else {
      return nil
    }

    var lo = 0
    var hi = points.count - 1

    while lo <= hi {
      let mid = (lo + hi) / 2

      if points[mid].date < date {
        lo = mid + 1
      } else {
        hi = mid - 1
      }
    }

    let after = points[lo]
    let before = lo > 0 ? points[lo - 1] : nil

    // Normal match: interpolate across a gap of
    // no more than five minutes.
    if let before {
      let gap = after.date.timeIntervalSince(before.date)

      if gap <= 5 * 60 {
        let fraction =
          date.timeIntervalSince(before.date) / gap

        return GPXMatch(
          latitude: before.latitude +
            (after.latitude - before.latitude) * fraction,
          longitude: before.longitude +
            (after.longitude - before.longitude) * fraction
        )
      }
    }

    // Fallback: first subsequent point within one hour.
    let difference = after.date.timeIntervalSince(date)

    if difference >= 0 && difference <= 60 * 60 {
      return GPXMatch(
        latitude: after.latitude,
        longitude: after.longitude
      )
    }

    return nil
  }
}