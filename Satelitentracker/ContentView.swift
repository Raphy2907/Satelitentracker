//
//  ContentView.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 24.04.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @Environment(\.modelContext) var SatelliteContext
    
    var body: some View {
        TabView{
            Tab("Satelliten", systemImage: "list.dash")
            {
                SatelliteListView()
            }
            Tab("Liste", systemImage: "clock")
            {
                ListAllPassesView()
            }
            Tab("Überflugkurve", systemImage: "point.forward.to.point.capsulepath.fill")
            {
                PolarPassView()
            }
            Tab("Steuerung", systemImage: "gear.circle")
            {
                MountControllView()
            }
            Tab("Tracking", systemImage: "arrowtriangle.right.circle")
            {
                TrackPassView()
            }
            
        }
        .modelContext(SatelliteContext)
        
    }
}
