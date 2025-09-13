
//
//  SatelliteListView.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 24.04.25.
//
import SwiftUI
import SwiftData
import Observation

struct SatelliteListView: View {

    @Environment(\.modelContext) var SatelliteContext
    @Query(sort: \SatelliteData_SaveModel.noradID) var satellite:
        [SatelliteData_SaveModel]
    @State var showAddSatelliteView: Bool = false
    @State var selectedSatelliteID: Int? = nil
    
    @Environment(SatelliteViewModel.self) private var SatVM

    var body: some View {
        NavigationStack {
            List {
                ForEach(satellite) { satellite in
                    HStack {
                        Button(action: {
                            Task {
                                SatVM.selectSatellite(for: satellite.noradID)
                                selectedSatelliteID = satellite.noradID
                            }
                            
                            
                        }) {
                            Image(systemName: selectedSatelliteID == satellite.noradID ? "circle.fill" : "circle")
                                .foregroundColor(selectedSatelliteID == satellite.noradID ? .blue : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                            .frame(width: 15)
                        
                        NavigationLink(value: satellite) {
                            VStack(alignment: .leading) {
                                Text("\(satellite.tle_data.name)")
                                    .frame(alignment: .leading)
                                    .fontWeight(.regular)
                               
                                Text(
                                    "NORAD ID: \(satellite.noradID.formatted(.number.grouping(.never)))"
                                )
                                .frame(alignment: .leading)
                                .fontWeight(.thin)
                                
                            }

                            
                        }
                    }

                }
                .onDelete(perform: deleteSatellite)
                Text("SatVM ist initialisiert: \(SatVM.isInitialized)")
            }
            .navigationTitle(Text("Satelliten"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Satellit hinzufügen", systemImage: "plus.circle") {
                        showAddSatelliteView.toggle()
                    }

                }

            }
            .sheet(isPresented: $showAddSatelliteView) {
                AddSatelliteView()
                    .environment(\.modelContext, SatelliteContext)
            }
            .navigationDestination(for: SatelliteData_SaveModel.self) {
                satellite in
                SatelliteDetailView(satID: satellite.noradID)
            }
        }
        .onAppear() {
            SatVM.triggerInitalUpdatePasses()
        }
    }

    func deleteSatellite(at offsets: IndexSet) {
        for offst in offsets {
            let satselected = satellite[offst]

            SatelliteContext.delete(satselected)
        }
    }
}
