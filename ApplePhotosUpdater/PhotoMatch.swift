//
//  PhotoMatch.swift
//  GeoTagger
//
//  Created by Ross Carter on 19/09/2026.
//


import Photos
import CoreLocation

struct PhotoMatch: Identifiable {
  let id: String
  let asset: PHAsset
  let date: Date
  let latitude: Double
  let longitude: Double
}