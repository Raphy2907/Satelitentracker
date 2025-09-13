//
//  TrackPassView.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 13.06.25.
//

import OSLog
import SatelliteKit
import SwiftData
import SwiftUI

struct AziEleSpeeds: Identifiable {
    var id: UUID

    var azimuth: Float
    var elevation: Float
    var azi_speed: Float
    var ele_speed: Float

    var doppler_144: Float
    var doppler_430: Float
}

struct TrackPassView: View {

    @Environment(\.modelContext) var SatelliteContext
    @Environment(SatelliteViewModel.self) private var SatVM
    
    @Query private var satellites: [SatelliteData_SaveModel]

    private var satellite: SatelliteData_SaveModel? {
        satellites.first { $0.noradID == SatID }
    }

    @Bindable var bleManager = myBluetoothService.shared

    @State private var passes: [NextPassesData] = []
    @State private var first_pass: NextPassesData?
    @State private var isdownloading: Bool = false
    @State private var SatID: Int = 0
    @State private var SatisSelected: Bool = false
    @State private var positionArrayPass: [AziEleSpeeds]?

    @State private var ZeitbisAufgang: TimeInterval = 5000
    @State private var ZeitbisUntergang: TimeInterval = 5000
    
    @State private var istAufgagangen: Bool = false
    @State private var timer: Timer?
    @State private var FünfMinutenbisStart: Bool = false
    @State private var TrackingisReady: Bool = false
    @State private var showHex = false
    @State private var showCountdownForIphonePlacement: Bool = false
    
    @State private var tensecIndex: Int = 0
    @State private var index_doppler: Int = 0
    @State private var doppler144: Float = 0.0
    @State private var doppler430: Float = 0.0
    @State private var diff144to430: Float = 0.0
    
    @State private var showSensorDialog: Bool = false
    
    private var showDialog: Bool {
        showSensorDialog
//        && bleManager.peripheralConnectionStatus == .connected
    }

    let columns = [
        GridItem(.fixed(250), alignment: .leading),
        GridItem(.fixed(100), alignment: .center),
    ]

    var body: some View {
        
        @Bindable var SatVMBinding = SatVM
        
        ScrollView {

            VStack {
                if !SatisSelected {
                    Text("Kein Satellite ausgewählt!")
                        .font(.title)
                } else {
                    Text(
                        "Tracking des nächsten Überflugs für \(satellite!.tle_data.name)"
                    )
                    .padding()
                    .font(.title)

                    Spacer()
                        .frame(height: 10)

                    if first_pass != nil {
                        
                        LazyVGrid(columns: columns) {
                            if(istAufgagangen){
                                Text("Zeit bis zum Untergang: ")
                                
                                Text(formatTime(ZeitbisUntergang))
                                    .monospaced()
                                    .foregroundColor(
                                        ZeitbisUntergang > 0 ? .green : .red
                                    )
                            } else {
                                Text("Zeit bis zum nächsten Überflug: ")
                                
                                Text(formatTime(ZeitbisAufgang))
                                    .monospaced()
                                    .foregroundColor(
                                        ZeitbisAufgang > 0 ? .green : .red
                                    )
                            }
                            
                            Text("Verbindungsstatus BLE: ")
                            
                            Circle()
                                .fill(
                                    bleManager.peripheralConnectionStatus
                                        .color
                                )
                                .frame(height: 15)
                            
                            Text("Positiondaten übermittelt: ")
                            
                            Circle()
                                .fill(
                                    bleManager.data_received
                                    ? Color.green : Color.red
                                )
                                .frame(height: 15)
                            
                            Text("Kalibrierung durchgeführt: ")
                            
                            Circle()
                                .fill(
                                    bleManager.compass_calibrated
                                    ? Color.green : Color.red
                                )
                                .frame(height: 15)
                            
                            if(SatVM.BNO085AsSensor) {
                                Text("Genauigkeit Rotation Vector: ")
                                
                                Circle()
                                    .fill(bleManager.accuracyIMU.color)
                                    .frame(height: 15)
                            }
                            
                            Text("Auf Startposition: ")
                            
                            Circle()
                                .fill(
                                    bleManager.at_startposition
                                    ? Color.green : Color.red
                                )
                                .frame(height: 15)
                            
                            Text("Aktueller Azimuthwinkel: ")
                            
                            Text(String(bleManager.akt_azimuth))
                            
                            Text("Aktueller Elevationwinkel: ")
                            
                            Text(String(bleManager.akt_elevation))
                            
                            if istAufgagangen {
                                Text("Dopplershift 2m: ")
                                
                                Text(String(doppler144))
                                
                                Text("Dopplershift 70cm: ")
                                
                                Text(String(doppler430))
                                
                                Text("Freuquenzdifferenz 70cm - 2m: ")
                                
                                Text(String(diff144to430))
                            }
                            
                        }
                        
                        Spacer()
                            .frame(height: 25)
                        
                        HStack {
                            Button("Verbinde mit TMP") {
                                bleManager.reconnect()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Select Sensor") {
                                showSensorDialog = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                       
                        
                        Button("Übermittle Trackingdata") {
                            Task {
                                positionArrayPass =
                                await SatVM.plotPathofSatellite(
                                    for: SatID,
                                    selectedPass: first_pass!
                                )
                                
                                guard positionArrayPass != nil else { return }
                                
                                let dataChunckes = SatVM.preparePassDataforTransmission(passData: positionArrayPass!)
                                
                                for databits in dataChunckes {
                                    
                                    //                                    print(databits)
                                    
                                    bleManager.writeCommand(
                                        databits,
                                        ESPChar: "Track"
                                    )
                                }
                                
                                let dataString =
                                "ANZAHL " + String(positionArrayPass!.count)
                                print(dataString)
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(
                                    data_comm,
                                    ESPChar: "Track"
                                )
                                
                                let dataString1 = "FERTIG"
                                let data_comm1 = dataString1.data(using: .utf8)!
                                bleManager.writeCommand(
                                    data_comm1,
                                    ESPChar: "Track"
                                )
                                
                                bleManager.processWriteQueue()
                                
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        if bleManager.senden_aktiv {
                            ProgressView(value: bleManager.progress_senden)
                                .progressViewStyle(
                                    LinearProgressViewStyle(tint: .blue)
                                )
                                .scaleEffect(x: 1, y: 0.5)
                        }
                        
                        HStack{
                            Button("Kalibrieren") {
                                SatVM.calibrateAndAlign()
                            }
                            .buttonStyle(.bordered)

                            Button("Fahre auf Startposition") {
                                let dataString = "AUSRICHTUNG"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(
                                    data_comm,
                                    ESPChar: ESPCharStatus.fernsteuer.string
                                )
                                bleManager.processWriteQueue()
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Toggle BLE Dataprint") {

                            let dataString = "TOGGLEBLE"
                            let data_comm = dataString.data(using: .utf8)!
                            bleManager.writeCommand(
                                data_comm,
                                ESPChar: ESPCharStatus.fernsteuer.string
                            )
                            bleManager.processWriteQueue()
                        }
                        .buttonStyle(.bordered)
                        
                        HStack{
                            Button("Starte Tracking!") {
                                //os_log("Ich sende den Startbefehl!")

                                let dataString = "START"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(
                                    data_comm,
                                    ESPChar: ESPCharStatus.fernsteuer.string
                                )
                                bleManager.processWriteQueue()
                            }
                            .buttonStyle(.bordered)

                            Button("Stoppe Tracking!") {
                                //os_log("Ich sende den Startbefehl!")

                                let dataString = "STOP"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(
                                    data_comm,
                                    ESPChar: ESPCharStatus.fernsteuer.string
                                )
                                bleManager.processWriteQueue()
                            }
                            .buttonStyle(.bordered)
                        }

                        
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Statusmeldungen")
                    .font(.headline)
                    .padding(.bottom, 10)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(bleManager.receivedMessages) { message in
                                MessageRow(message: message, showHex: false)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: bleManager.receivedMessages.count) { _ in
                        // Auto-scroll zu neuester Nachricht
                        if let lastMessage = bleManager.receivedMessages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color.gray.opacity(0.25))
            .cornerRadius(10)
        }
        .onAppear {
            passes = []
            if let x1 = SatVM.returnSatID() {
                SatID = x1
                SatisSelected = true
                Task {
                    let x2 = await SatVM.returnPasses(for: SatID)
                    if x2 != nil {
                        first_pass = x2!.first!
                        startTimer()
                    }
                }
            }

        }
        .onDisappear {
            istAufgagangen = false
            timer?.invalidate()
            timer = nil
        }
        .alert("Sensor auswählen", isPresented: .constant(showDialog)) {
            Button("BNO085") {
                SatVM.BNO085AsSensor = true
                showSensorDialog = false
                SatVM.selectSensor()
            }
            
            Button("IPhone") {
                SatVM.IphoneAsSensor = true
                showSensorDialog = false
                SatVM.selectSensor()
                SatVM.CountdownIphonePlacement = 20
            }
        } message: {
            Text("Bitte zwischen einem externen BNO085 Orientierungssensor oder dem IPhone als Sensor für Ausrichtungsdaten wählen!")
        }
        
        .sheet(isPresented: $SatVMBinding.showCountdownDialog) {
            CountdownView(wirdAngezeigt: $showCountdownForIphonePlacement)
                .presentationDetents([.medium, .large])
        }
    }

    private func startTimer() {
        guard first_pass != nil else { return }

        berechneVerbleibendeZeit()
        
        if positionArrayPass != nil {
            doppler144 = positionArrayPass![index_doppler].doppler_144
            doppler430 = positionArrayPass![index_doppler].doppler_430
            diff144to430 = doppler430 - doppler144
        }
        

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            _ in
            
            tensecIndex += 1
            if istAufgagangen {
                zeigeDoppler()
            } else {
                berechneVerbleibendeZeit()
            }
        }
    }

    private func berechneVerbleibendeZeit() {
        guard let pass = first_pass else { return }

        let Aufgangszeit = Date(
            timeIntervalSince1970: TimeInterval(pass.startUTC)
        )

        let zeitdifferenz = Aufgangszeit.timeIntervalSince(Date())

        ZeitbisAufgang = max(0, zeitdifferenz)

        if ZeitbisAufgang <= 0 {
            guard !bleManager.start_gesendet else { return }

//            os_log("Ich sende den Startbefehl!")

            let dataString = "START"
            let data_comm = dataString.data(using: .utf8)!
            bleManager.writeCommand(
                data_comm,
                ESPChar: ESPCharStatus.fernsteuer.string
            )
            bleManager.start_gesendet = true
            bleManager.processWriteQueue()
            
            istAufgagangen = true
        }

    }
    
    private func zeigeDoppler() {

        guard let pass = first_pass else { return }
        
        let Untergangszeit = Date(
            timeIntervalSince1970: TimeInterval(pass.endUTC)
        )
        
//        print(Untergangszeit)
        
        let now = Date()
        let zeitdifferenz = Untergangszeit.timeIntervalSince(now)
        
//        print(zeitdifferenz)

        ZeitbisUntergang = max(0, zeitdifferenz)
        
        guard positionArrayPass != nil else {
            return
        }
        
        if index_doppler > positionArrayPass!.count - 1 {
            stopTimer()
            return
        }
                
        if tensecIndex > 9 {
            doppler144 = positionArrayPass![index_doppler].doppler_144
            doppler430 = positionArrayPass![index_doppler].doppler_430
            diff144to430 = doppler430 - doppler144
            index_doppler += 20
            tensecIndex = 0
        }
        
        
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        index_doppler = 0
        tensecIndex = 0
        istAufgagangen = false
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

}

struct MessageRow: View {
    let message: BLEMessage
    let showHex: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                if showHex {
                    Text("\(message.data.count) Bytes")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text(showHex ? message.hexString : message.text)
                .font(.system(.body, design: .monospaced))
                .padding(8)

        }
    }
}

struct CountdownView: View {
    @Environment(SatelliteViewModel.self) private var SatVM
    
    @Binding var wirdAngezeigt: Bool
    
    var body: some View {
        VStack (spacing: 30){
            
            if(SatVM.StarteCountdownforIphoneACC) {
                Text("Das Iphone zur Verbessrung der Sensorgenauigkeit in einer Acht bewegen!")
                
                Spacer()
                    .frame(height: 10)
                Text("Noch \(SatVM.CountdownIphoneAccurary) Sekunden bis die interne Kalibrierung endet!")
                
                Button("Abbrechen!") {
                    SatVM.wurdeAbbgebrochen = true
                    SatVM.stopCountdownTimerAcc()
                    SatVM.stopAlignment()
                    wirdAngezeigt = false
                }
            } else if (SatVM.StarteCountdownforIphoneAlignment) {
                Text("IPhone bitte in die entsprechende Halterung am Trackmount legen!")
                Spacer()
                    .frame(height: 10)
                Text("Noch \(SatVM.CountdownIphonePlacement) Sekunden bis die Kalibrierung startet!")
                
                Button("Abbrechen!") {
                    SatVM.wurdeAbbgebrochen = true
                    SatVM.stopCountdownTimer()
                    SatVM.stopAlignment()
                    wirdAngezeigt = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
