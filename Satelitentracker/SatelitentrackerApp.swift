//
//  SatelitentrackerApp.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 24.04.25.
//

import SwiftUI
import SwiftData

@main
struct SatelitentrackerApp: App {
    
    let container : ModelContainer = {
        do {
            return try ModelContainer(for: SatelliteData_SaveModel.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(SatelliteViewModel.shared)
                .onAppear {
                    SatelliteViewModel.shared.initialize(with: container)
                }
        }

    }
}
