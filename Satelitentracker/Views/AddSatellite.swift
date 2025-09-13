//
//  AddSatellite.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 09.05.25.
//
import Foundation
import SwiftUI
import SwiftData

struct AddSatelliteView: View {
    
    @Environment(\.modelContext) var SatelliteContext
    @Environment(SatelliteViewModel.self) var SatVM
    
    @State private var name: String = ""
    @State private var noradID: Int = 0
    @State private var beschreibung: String = ""
    @State private var TLE_downloaded: Bool = false
    
    @State var tleLine1: String = ""
    @State var tleLine2: String = ""

    var body: some View {
        Form{
            Section(header: Text("Satellitensuche")) {
                VStack{
                    HStack{
                        Text("NORAD ID:")
                        TextField("", value: $noradID, formatter: NumberFormatter())
                            .keyboardType(UIKeyboardType.decimalPad)
                    }
                   
                }

            }
            Button("Suche Satellit") {
                Task {
                    await SatVM.updateTLEData(for: noradID)
                }
            }
        }
    }
}


