//
//  DiagnosticsView.swift
//  GeoTagger
//

import SwiftUI

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
            Text("\(item.total)").monospacedDigit()
            Text("\(item.geotagged)").monospacedDigit()
            Text("\(item.untagged)").monospacedDigit()
            Text("\(item.matched)").monospacedDigit()
            Text("\(item.unmatched)").monospacedDigit()
          }
        }

        Divider()
          .gridCellColumns(6)

        GridRow {
          Text("Total")
            .fontWeight(.semibold)

          Text("\(diagnostics.reduce(0) { $0 + $1.total })")
          Text("\(diagnostics.reduce(0) { $0 + $1.geotagged })")
          Text("\(diagnostics.reduce(0) { $0 + $1.untagged })")
          Text("\(diagnostics.reduce(0) { $0 + $1.matched })")
          Text("\(diagnostics.reduce(0) { $0 + $1.unmatched })")
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
