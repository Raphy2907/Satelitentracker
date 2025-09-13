//
//  SatelliteDetailView.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 18.05.25.
//

import OSLog
import Observation
import SwiftData
import SwiftUI

enum FocusedView: Hashable {
    case TextFieldBeschreibung
    case keinFocus
}

struct SatelliteDetailView: View {

    let satID: Int

    @Environment(\.modelContext) var SatelliteContext
    @Environment(SatelliteViewModel.self) private var SatVM
    @Query private var satellites: [SatelliteData_SaveModel]

    private var satellite: SatelliteData_SaveModel? {
        satellites.first { $0.noradID == satID }
    }

    @State private var EinabgeBuffer: String = "Bitte etwas eingeben!"
    @State private var neuerSatellitenName: String = ""
    @State private var inputSaved: Bool = false
    @State private var zeigeNamensDialog: Bool = false
    @State private var satType: SatelliteType = .undefiniert
    @State private var transponderType: TransponderType = .fm
    @FocusState private var isFocused: FocusedView?

    @State private var hasDownloadedPasses: Bool = false

    @State private var hamSatFrequenzen: AmateurfunkSatellite =
        AmateurfunkSatellite(
            uplink_freq: 0.0,
            downlink_freq: 0.0,
            transponderArt: .fm
        )

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Infos")) {
                    HStack {
                        Text("Name: \(satellite!.tle_data.name)")
                        Button("Name ändern") {
                            neuerSatellitenName = satellite!.tle_data.name
                            zeigeNamensDialog = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text(
                        "NORAD ID: \(satellite!.noradID.formatted(.number.grouping(.never)))"
                    )

                }
                .alert("Name ändern", isPresented: $zeigeNamensDialog) {
                    TextField("Neuer Name", text: $neuerSatellitenName)
                        .textInputAutocapitalization(.never)
                    Button("Speichern") {
                        Task {
                            let _ = await SatVM.updateSatName(
                                for: satID,
                                name: neuerSatellitenName
                            )
                        }

                    }
                    .disabled(
                        neuerSatellitenName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )

                    Button("Abbrechen", role: .cancel) {
                        neuerSatellitenName = ""
                    }
                } message: {
                    Text("Gib einen neuen Namen für den Satelliten ein.")
                }

                Section(header: Text("Comm-Frequenzen")) {
                    VStack(alignment: .leading) {
                        Picker("Satellitentyp", selection: $satType) {
                            ForEach(SatelliteType.allCases, id: \.self) {
                                type in
                                Text(type.displayName).tag(type)
                            }

                        }

                        if satType == .hamSat {

                            Picker(
                                "Transpondertyp",
                                selection: $transponderType
                            ) {
                                ForEach(TransponderType.allCases, id: \.self) {
                                    type in
                                    Text(type.displayName)
                                        .tag(type)
                                        .font(.system(size: 12))
                                }

                            }
                            .onChange(of: transponderType) {
                                hamSatFrequenzen.transponderArt =
                                    transponderType
                            }

                            HStack {
                                Text("Uplinkfrequenz in kHz")
                                    .font(.system(size: 14))
                                TextField(
                                    "",
                                    text: Binding(
                                        get: {
                                            String(hamSatFrequenzen.uplink_freq)
                                        },
                                        set: {
                                            hamSatFrequenzen.uplink_freq =
                                                Double($0) ?? 0.0
                                        }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)

                            }

                            HStack {
                                Text("Downlinkfrequenz in kHz")
                                    .font(.system(size: 14))
                                TextField(
                                    "",
                                    text: Binding(
                                        get: {
                                            String(
                                                hamSatFrequenzen.downlink_freq
                                            )
                                        },
                                        set: {
                                            hamSatFrequenzen.downlink_freq =
                                                Double($0) ?? 0.0
                                        }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            }

                            Button("Speichere Comm Daten") {
                                Task {
                                    await SatVM.saveCommData(
                                        for: satID,
                                        TypeofSat: .hamSat(hamSatFrequenzen)
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section(header: Text("Bahndaten")) {
                    VStack(alignment: .leading) {
                        Text(
                            "Inklination: \(satellite!.tle_data.inklination, specifier: "%.2f")°"
                        )
                        //                        Text(
                        //                            "RAAN: \(satellite!.tle_data.raan, specifier: "%.2f")°"
                        //                        )
                        //                        Text(
                        //                            "Exzentrizität: \(satellite!.tle_data.excentricity, specifier: "%.6f")"
                        //                        )
                        //                        Text(
                        //                            "Argument Perigäum: \(satellite!.tle_data.argofperigee, specifier: "%.2f")°"
                        //                        )
                        //                        Text(
                        //                            "Mittlere Anomalie: \(satellite!.tle_data.mittlereanomalie, specifier: "%.2f")°"
                        //                        )
                        Text(
                            "Mittlere Bewegung: \(satellite!.tle_data.mittlerebewegung, specifier: "%.2f")"
                        )
                        //                        Text(
                        //                            "Umläufe seit Start: \(Int(satellite!.tle_data.nummerumlauf))"
                        //                        )
                        //
                        //                        Spacer()
                        //                            .frame(height: 10)

                        Text(
                            "Epochenjahr: \(satellite!.tle_data.epoch_year.formatted(.number.grouping(.never)))"
                        )
                        Text("Epochentage: \(satellite!.tle_data.epoch_days)")

                    }

                }

                Section(header: Text("Beschreibung")) {

                    TextEditor(
                        text: Binding(
                            get: { satellite!.beschreibung ?? "" },
                            set: { satellite!.beschreibung = $0 }
                        )
                    )
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .focused($isFocused, equals: .TextFieldBeschreibung)
                    .padding(2)

                }

                Section(header: Text("Nächste Überflüge")) {
                    VStack{
                        Text(
                            "Anzahl der gespeicherten Überflüge: \(satellite!.passes_count)"
                        )
                        
                        Text(
                            "Datum des Downloads: \(satellite!.passes_downloaddate?.dayMonthHourMinute ?? Date().dayMonthHourMinute)"
                        )
                    }

                    Button(action: {
                        Task {
                            hasDownloadedPasses = await SatVM.updatePasses(
                                for: satID
                            )
                        }
                    }) {
                        if satellite!.passes_downloaded {
                            Text("Downloade Nächste Überflüge")
                        } else {
                            Text("Update Nächste Überflüge")
                        }
                    }

                    if !(satellite!.passes_downloaded) {
                        Text("Keine Überflüge in der Datenbank!")
                    } else {
                        ForEach(satellite!.nextPasses!, id: \.self) { pass in
                            Text(
                                "Nächster Überflug am \(Date(timeIntervalSince1970: TimeInterval(pass.startUTC)).dayMonthHourMinute)"
                            )
                        }

                    }
                }
            }
        }
        .onAppear {
            Task {
                await SatVM.removeOldPasses(for: satID)
            }

            if satellite!.satType != nil {
                satType = satellite!.satType!

                if satType == .hamSat {
                    hamSatFrequenzen = AmateurfunkSatellite(
                        uplink_freq: satellite!.AmateurfunkFruequency!
                            .uplink_freq,
                        downlink_freq: satellite!.AmateurfunkFruequency!
                            .downlink_freq,
                        transponderArt: satellite!.AmateurfunkFruequency!
                            .transponderArt
                    )

                    transponderType = hamSatFrequenzen.transponderArt
                }

            }

        }

        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    hideKeyboard()
                }
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
