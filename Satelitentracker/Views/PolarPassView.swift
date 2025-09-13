//
//  PolarPassView.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 28.05.25.
//

import Foundation
import OSLog
import SatelliteKit
import SwiftData
import SwiftUI

struct PolarPassView: View {

    var polarPassVM = PolarPassViewModel()

    @Environment(\.modelContext) var SatelliteContext
    @Environment(SatelliteViewModel.self) private var SatVM

    @State var SatisSelected: Bool = false
    @State var passes: [NextPassesData] = []
    @State var selectedPass: NextPassesData?
    @State var isdownloading: Bool = false
    @State var SatID: Int = 0
    @State var positionArrayPass: [AziEleSpeeds]?

    @Query private var satellites: [SatelliteData_SaveModel]

    private var satellite: SatelliteData_SaveModel? {
        satellites.first { $0.noradID == SatID }
    }

    var body: some View {
//        ScrollView {
            VStack {
                if !SatisSelected {
                    Text("Kein Satellite ausgewählt!")
                        .font(.title)
                } else {
                    Text("Überflugvorhersage für \(satellite!.tle_data.name)")
                        .font(.title)
                    
                    if !passes.isEmpty {
                        Picker(
                            "Bitte einen Überflug auswählen",
                            selection: $selectedPass
                        ) {
                            ForEach(passes, id: \.self) { pass in
                                Text(
                                    Date(
                                        timeIntervalSince1970: TimeInterval(
                                            pass.startUTC
                                        )
                                    ).dayMonthHourMinute
                                ).tag(pass)
                            }
                        }
                        .pickerStyle(.wheel)
                        
                        Spacer()
                            .frame(height: 5)
                        
                        Button("Berechne Flugbahn") {
                            positionArrayPass = nil
                            guard let selectedPass else {
                                os_log("selectedPass enthält keinen Wert!")
                                return
                            }
                            Task {
                                positionArrayPass = await SatVM.plotPathofSatellite(
                                    for: SatID,
                                    selectedPass: selectedPass
                                )
                            }
                            
                        }
                        .buttonStyle(.bordered)
                        
                    } else if isdownloading {
                        Text("Daten werden geladen...")
                        
                    } else {
                        Text(
                            "Es wurden noch keine Überflugsdaten für das ausgewählte Satellite abgerufen."
                        )
                    }
                    
                    Canvas { context, size in
                        polarPassVM.drawPolarGrid(context: context, size: size)
                        if positionArrayPass != nil {
                            polarPassVM.drawPath(
                                context: context,
                                size: size,
                                positionArrayPass: positionArrayPass!
                            )
                        }
                        
                    }
                    .frame(width: 400, height: 400)
                    .background(Color.black)
                    .cornerRadius(10)
                    .scaledToFit()
                    
//                    if positionArrayPass != nil {
//                        LazyVStack(alignment: .center, spacing: 5, pinnedViews: [])
//                        {
//                            HStack {
//                                Text("Azimuth")
//                                    .frame(width: 80)
//                                
//                                Text("Azimuthspeed")
//                                    .frame(width: 80)
//                                
//                                Text("Elevation")
//                                    .frame(width: 80)
//                                
//                                Text("Elevationspeed")
//                                    .frame(width: 80)
//                            }
//                            .font(.system(size: 12))
//                            
//                            Divider()
//                            
//                            ForEach(positionArrayPass!) { positions in
//                                HStack {
//                                    Text(String(format: "%.1f°", positions.azimuth))
//                                        .frame(width: 80)
//                                    
//                                    Text(
//                                        String(format: "%.2f°", positions.azi_speed)
//                                    )
//                                    .frame(width: 80)
//                                    
//                                    Text(
//                                        String(format: "%.1f°", positions.elevation)
//                                    )
//                                    .frame(width: 80)
//                                    
//                                    Text(
//                                        String(format: "%.2f°", positions.ele_speed)
//                                    )
//                                    .frame(width: 80)
//                                }
//                                
//                            }
//                        }
//                    }
                }
            }
//        }
        .onAppear {
            passes = []
            if let x1 = SatVM.returnSatID() {
                SatID = x1
                SatisSelected = true
                Task {
                    let x2 = await SatVM.returnPasses(for: SatID)
                    if x2 != nil {
                        passes = x2!
                        selectedPass = passes.first
                    }
                }
            }
        }
    }
}

#Preview {
    PolarPassView()
}
