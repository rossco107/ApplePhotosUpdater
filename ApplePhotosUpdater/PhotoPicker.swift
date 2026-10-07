//
//  PhotoPicker.swift
//  GeoTagger
//
//  Created by Ross Carter on 19/09/2026.
//

import SwiftUI
import PhotosUI

struct PhotoPicker: NSViewControllerRepresentable {
  @Binding var isPresented: Bool
  let onSelection: ([String]) -> Void

  func makeNSViewController(context: Context) -> PHPickerViewController {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 0

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = context.coordinator
    return picker
  }

  func updateNSViewController(
    _ nsViewController: PHPickerViewController,
    context: Context
  ) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  final class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let parent: PhotoPicker

    init(_ parent: PhotoPicker) {
      self.parent = parent
    }

    func picker(
      _ picker: PHPickerViewController,
      didFinishPicking results: [PHPickerResult]
    ) {
      let identifiers = results.compactMap {
        $0.assetIdentifier
      }

      print("Photos selected:", identifiers.count)
      parent.onSelection(identifiers)
      parent.isPresented = false
    }
  }
}
