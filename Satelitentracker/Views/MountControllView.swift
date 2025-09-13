//
//  MountControllView.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 21.05.25.
//

import SwiftUI

struct MountControllView: View {
    @Bindable var bleManager = myBluetoothService.shared
    @Environment(SatelliteViewModel.self) private var SatVM

    @State var selectedVelocity: Double = 0.01
    let velocityOptions: [Double] = [1, 2, 3, 4, 5, 10, 20]
    @State private var showSensorDialog: Bool = false
    @State private var showCountdownForIphonePlacement: Bool = false
    
    private var showDialog: Bool {
        showSensorDialog
//        && bleManager.peripheralConnectionStatus == .connected
    }

    var body: some View {
        
        @Bindable var SatVMBinding = SatVM
        
        ScrollView {
            VStack{
                Text("Satellitentrackmount Steuerung")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Spacer()
                    .frame(height: 5)

                HStack(spacing: 10) {
                    Text("Verbindungsstatus: ")
                    Circle()
                        .fill(bleManager.peripheralConnectionStatus.color)
                        .frame(maxHeight: 20)
                }
                
                Spacer()
                    .frame(height: 5)
                
                Button("Versuche erneute Verbindung") {
                    bleManager.reconnect()
                }
                .padding()
                .buttonStyle(.bordered)
                
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

                VStack {
                    Button(action: {
                        let dataString = "EU" + String(Int(selectedVelocity))
                        let data_comm = dataString.data(using: .utf8)!
                        bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                        bleManager.processWriteQueue()
                    }) {
                        Color.clear
                    }
                    .background(Color.blue)
                    .clipShape(ArrowShape(direction: .up))
                    .contentShape(ArrowShape(direction: .up))
                    .frame(width: 40, height: 80)

                    HStack {
                        Button(action: {
                            let dataString = "AL" + String(Int(selectedVelocity))
                            let data_comm = dataString.data(using: .utf8)!
                            bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                            bleManager.processWriteQueue()
                        }) {
                            Color.clear
                                
                        }
                        .background(Color.blue)
                        .clipShape(ArrowShape(direction: .left))
                        .contentShape(ArrowShape(direction: .left))
                        .frame(width: 80, height: 40)

                        Button(action: {
                            let dataString = "STMOTOR"
                            let data_comm = dataString.data(using: .utf8)!
                            bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                            bleManager.processWriteQueue()
                        }) {
                            Color.clear
                                
                        }
                        .background(Color.blue)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .frame(width: 40, height: 40)

                        Button(action: {
                            let dataString = "AR" + String(Int(selectedVelocity))
                            let data_comm = dataString.data(using: .utf8)!
                            bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                            bleManager.processWriteQueue()
                        }) {
                            Color.clear
                                
                        }
                        .background(Color.blue)
                        .clipShape(ArrowShape(direction: .right))
                        .contentShape(ArrowShape(direction: .right))
                        .frame(width: 80, height: 40)
                    }

                    Button(action: {
                        let dataString = "ED" + String(Int(selectedVelocity))
                        let data_comm = dataString.data(using: .utf8)!
                        bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                        bleManager.processWriteQueue()
                    }) {
                        Color.clear
                            
                    }
                    .background(Color.blue)
                    .clipShape(ArrowShape(direction: .down))
                    .contentShape(ArrowShape(direction: .down))
                    .frame(width: 40, height: 80)

                    Spacer()
                        .frame(height: 20)

                    Picker("Drehgeschwindigkeit:", selection: $selectedVelocity) {
                        ForEach(velocityOptions, id: \.self) { option in
                            Text(String(option))
                        }
                    }.pickerStyle(.segmented)
                    
                    Spacer()
                    
                    VStack (spacing: 5) {
                        HStack {
                            Button("Status abfragen", action: {
                                let dataString = "STATUS"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                                bleManager.processWriteQueue()
                            })
                            .buttonStyle(.bordered)
                            
                            Button("Kalibration") {
                                SatVM.calibrateAndAlign()
                            }
                            .buttonStyle(.bordered)
                        }
                                                
                        Button("Übermittle Mag. Declination", action: {
                            let dataString = "DECLINATION 1.75"
                            let data_comm = dataString.data(using: .utf8)!
                            bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                            bleManager.processWriteQueue()
                        })
                        .buttonStyle(.bordered)
                        
                        HStack {
                            Button("Enable Motors", action: {
                                let dataString = "ENABLE"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                                bleManager.processWriteQueue()
                            })
                            .buttonStyle(.bordered)
                            
                            Button("Disable Motors", action: {
                                let dataString = "DISABLE"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                                bleManager.processWriteQueue()
                            })
                            .buttonStyle(.bordered)
                            
                            Button("Ausrichtung Norden", action: {
                                let dataString = "NORTH"
                                let data_comm = dataString.data(using: .utf8)!
                                bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
                                bleManager.processWriteQueue()
                            })
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
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
//                showCountdownForIphonePlacement = true
                SatVM.CountdownIphonePlacement = 20
//                SatVM.startCountdownTimer()
                
            }
        } message: {
            Text("Bitte zwischen einem externen BNO085 Orientierungssensor oder dem IPhone als Sensor für Ausrichtungsdaten wählen!")
        }
        
        .sheet(isPresented: $SatVMBinding.showCountdownDialog) {
            CountdownView(wirdAngezeigt: $showCountdownForIphonePlacement)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        
        .padding(1)

    }

}
