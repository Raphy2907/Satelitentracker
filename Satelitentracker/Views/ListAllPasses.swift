//
//  ListAllPasses.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 18.08.25.
//

import Foundation
import SwiftUI

struct ListAllPassesView: View {

    @Environment(SatelliteViewModel.self) private var SatVM
    @State private var passes: [PassDataforOverview] = []
    @State private var loaded: Bool = false
    @State private var loading: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if loaded {
                    ForEach(passes.indices, id: \.self) { index in
                        PassRowView(passInfo: passes[index], rank: index + 1)
                    }

                } else if loading {
                    Text("Übersicht wird gerade geladen ...")
                }
            }
            .navigationTitle("Nächsten Überflüge")
        }

        .onAppear {

            Task {
                loading = true
                loaded = false
                let tempPasses = await SatVM.loadPassesforOverview()
                if tempPasses != nil {
                    passes = tempPasses!
                    loading = false
                    loaded = true

                }
            }
            

        }

    }

}

struct PassRowView: View {
    let passInfo: PassDataforOverview
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(rank)")
                    .font(.headline)
                    .frame(width: 45, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(passInfo.satelliteName)

                        if let type = passInfo.satelliteType {
                            Text(type.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(typeColor(for: type))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()
            }

            Divider()

            // Pass-Details
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ],
                spacing: 12
            ) {
                PassDetailItem(
                    title: "Start",
                    value: formatTime(passInfo.pass.startUTC),
                    subtitle: formatDate(passInfo.pass.startUTC)
                )

                PassDetailItem(
                    title: "Ende",
                    value: formatTime(passInfo.pass.endUTC),
                    subtitle:
                        "Dauer: \(formatDuration(passInfo.pass.endUTC - passInfo.pass.startUTC))"
                )

                PassDetailItem(
                    title: "Max. Höhe",
                    value: "\(Int(passInfo.pass.maxEl))°",
                    subtitle: formatTime(Double(passInfo.pass.maxUTC))
                )
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func typeColor(for type: SatelliteType) -> Color {
        switch type {
        case .weatherSat:
            return .green
        case .hamSat:
            return .orange
        case .undefiniert:
            return .gray
        }
    }

    private func formatTime(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}

struct PassDetailItem: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
