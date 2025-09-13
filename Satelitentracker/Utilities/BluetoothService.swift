//
//  BluetoothService.swift
//  BLE_TestApp
//
//  Created by Raphael Schwierz on 27.05.25.
//

import CoreBluetooth
import Foundation
import SwiftUI
import os

enum connectionStatus {
    case connected, disconnected, searching, connecting, error

    var color: Color {
        switch self {
        case .connected:
            return .green
        case .disconnected:
            return .purple
        case .searching:
            return .yellow
        case .connecting:
            return .blue
        case .error:
            return .red
        }
    }
}

enum accuracyIMU {
    case zero, one, two, three

    var color: Color {
        switch self {
        case .zero:
            return .red
        case .one:
            return .orange
        case .two:
            return .yellow
        case .three:
            return .green
        }
    }
}

enum ESPCharStatus {
    case fernsteuer, track, align

    var string: String {
        switch self {
        case .fernsteuer:
            return "Fernsteuer"
        case .track:
            return "Track"
        case .align:
            return "Align"
        }
    }
}

struct BLEMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let data: Data
    let text: String
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var hexString: String {
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

struct BLEWriteDataQueue {
    var data_queue: Data
    var char: CBCharacteristic
}

let ESP32PeripheralUUIDString: CBUUID = CBUUID(
    string: "4bffbae9-8de9-923b-20b6-cda8cf1497e7"
)

let ESP32ServiceUUIDString: CBUUID = CBUUID(
    string: "23d38c42-ca61-4f21-811a-2ebf20b1fe3f"
)

let ESP32FernsteuerCharUUID: CBUUID = CBUUID(
    string: "59cc30a6-ba63-4fda-9e62-279244235c46"
)

let ESP32TrackCharUUID: CBUUID = CBUUID(
    string: "94a2502c-af75-4247-9ed4-f6b3668de37d"
)

let ESP32StatusCharUUID: CBUUID = CBUUID(
    string: "7baa50c6-0d2d-417d-8607-ac1f85d209f7"
)

let ESP32AlignCharUUID: CBUUID = CBUUID(
    string: "c882db6a-5a3a-46a3-ba74-9e1e2f5c71d8"
)

@Observable
class myBluetoothService: NSObject {

    var receivedMessage: String = ""
    var data_received: Bool = false
    var compass_calibrated: Bool = false
    var at_startposition: Bool = false
    var start_gesendet: Bool = false
    var akt_azimuth: Float = 0.0
    var akt_elevation: Float = 0.0
    var senden_aktiv: Bool = false
    var progress_senden: Float = 0.0
    var anzahl_gesendete_bytes: Int = 0
    var anzahl_zusendende_bytes: Int = 0
    var alignmentIsFinished: Bool = false

    static let shared = myBluetoothService()
    private var centralManager: CBCentralManager!

    var data_out: Int = 0

    var ESP32Peripheral: CBPeripheral?
    var ESP32FernsteuerChar: CBCharacteristic?
    var ESP32TrackChar: CBCharacteristic?
    var ESPaktiveChar: CBCharacteristic?
    var ESP32StatusChar: CBCharacteristic?
    var ESP32AlignChar: CBCharacteristic?

    var peripheralConnectionStatus: connectionStatus = .disconnected
    @Published @ObservationIgnored var peripheralConnectionStatusforSubscriptions: connectionStatus = .disconnected
    var accuracyIMU: accuracyIMU = .zero

    private var writeQueue: [BLEWriteDataQueue] = []
    private var isWriting: Bool = false
    
    var receivedMessages: [BLEMessage] = []

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        os_log("Bluetooth initialisiert!")
    }

    func scanForPeripherals() {
        os_log("Scanning for peripherals...")
        centralManager.scanForPeripherals(withServices: nil)
        peripheralConnectionStatus = .searching

    }

    func writeCommand(_ command: Data, ESPChar: String) {
        if ESPChar == "Fernsteuer" {
            ESPaktiveChar = ESP32FernsteuerChar
        } else if ESPChar == "Track" {
            ESPaktiveChar = ESP32TrackChar
        } else if ESPChar == "Align" {
            ESPaktiveChar = ESP32AlignChar
        }

        guard ESPaktiveChar != nil,
            ESP32Peripheral != nil,
            peripheralConnectionStatus == .connected
        else {
            //           os_log( "Not connected to ESP32!")
            return
        }

        writeQueue.append(BLEWriteDataQueue(data_queue: command, char: ESPaktiveChar!))
        
//        print(writeQueue)
        if ESPaktiveChar == ESP32TrackChar {
            if !senden_aktiv {
                senden_aktiv = true
            }
        }
        
        
        if ESPaktiveChar == ESP32TrackChar {
            anzahl_zusendende_bytes += 1
        }
        //processWriteQueue()

    }

    func processWriteQueue() {
        
        var aktiveChar : CBCharacteristic?


        guard !isWriting else {
            os_log("Error: Not ready to write command!")
            return
        }
        
        guard !writeQueue.isEmpty else {
            senden_aktiv = false
            anzahl_gesendete_bytes = 0
            anzahl_zusendende_bytes = 0
            progress_senden = 0.0
            return
        }

        let nextMessage = writeQueue.removeFirst()
        aktiveChar = nextMessage.char
        let command = nextMessage.data_queue
        guard let char = aktiveChar,
            let peri = ESP32Peripheral
        else {
            os_log("Fehler!")
            return
        }

        isWriting = true
        peri.writeValue(command, for: char, type: .withResponse)
        
        if aktiveChar == ESP32TrackChar {
            anzahl_gesendete_bytes += 1
            progress_senden = Float(anzahl_gesendete_bytes) / Float(anzahl_zusendende_bytes)
        }
        

    }

    func reconnect() {
        guard peripheralConnectionStatus == .disconnected else {
            os_log("Verbindung besteht noch, kann nicht reconnecten!")
            return
        }

        scanForPeripherals()
    }

    func reset_connection() {
        data_received = false
        compass_calibrated = false
        at_startposition = false
        start_gesendet = false
        accuracyIMU = .zero
    }
    
    private func addMessage(_ data: Data) {
        let message = BLEMessage(
            timestamp: Date(),
            data: data,
            text: String(data: data, encoding: .utf8) ?? "Unlesbare Daten"
        )
        
        DispatchQueue.main.async {
            self.receivedMessages.append(message)
            // Nur die letzten 10 Nachrichten behalten
            if self.receivedMessages.count > 10 {
                self.receivedMessages.removeFirst()
            }
        }
    }

}

extension myBluetoothService: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            os_log("CB Powered ON!")
            //            scanForPeripherals()
        } else {
            os_log("CB not Powered ON!")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {

        if peripheral.name == "Test_Server" {
            //            print("UUID: \(peripheral.identifier.uuidString), Name: \(peripheral.name ?? "Unknown")")
            //            print("Connected to Test Server!")
            ESP32Peripheral = peripheral
            centralManager.connect(ESP32Peripheral!)
            peripheralConnectionStatus = .connecting
        }

    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        peripheralConnectionStatus = .connected
        peripheralConnectionStatusforSubscriptions = .connected

        peripheral.delegate = self
        peripheral.discoverServices([ESP32ServiceUUIDString])
        centralManager.stopScan()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        peripheralConnectionStatus = .disconnected
        peripheralConnectionStatusforSubscriptions = .disconnected
        print(error ?? "No Error")
        reset_connection()

    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        peripheralConnectionStatus = .error
        os_log("Connection failed")
    }
}

extension myBluetoothService: CBPeripheralDelegate {

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        for service in peripheral.services ?? [] {
            if service.uuid == ESP32ServiceUUIDString {
                peripheral.discoverCharacteristics(
                    [ESP32FernsteuerCharUUID, ESP32TrackCharUUID, ESP32StatusCharUUID, ESP32AlignCharUUID],
                    for: service
                )
            }

        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        for characteristic in service.characteristics ?? [] {
            print("Unbekannter Characteristic UUID: \(characteristic.uuid) - \(characteristic.description)")
            if characteristic.uuid == ESP32FernsteuerCharUUID {
                os_log("FernsteuerChar gefunden")
                myBluetoothService.shared.ESP32FernsteuerChar = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            else if characteristic.uuid == ESP32TrackCharUUID {
                os_log("TrackingChar gefunden")
                myBluetoothService.shared.ESP32TrackChar = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            else if characteristic.uuid == ESP32StatusCharUUID {
                os_log("StatusChar gefunden")
                myBluetoothService.shared.ESP32StatusChar = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            else if characteristic.uuid == ESP32AlignCharUUID {
                os_log("AlignChar gefunden")
                myBluetoothService.shared.ESP32AlignChar = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }

        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        isWriting = false

        if let error {
            //            os_log("Fehler!")
            print(error)
        } else {
            //            os_log("Befehl gesendet!")
        }
        if !writeQueue.isEmpty {
            processWriteQueue()
        } else {
            senden_aktiv = false
            anzahl_gesendete_bytes = 0
            anzahl_zusendende_bytes = 0
            progress_senden = 0.0
        }
        
        

    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        //        os_log("Ich empfange was!")
        if let error = error {
            os_log("Read error: %@", error.localizedDescription)
            return
        }
        
//        print(characteristic.uuid)
        
        if characteristic.uuid == ESP32AlignCharUUID {
            if let data = characteristic.value,
                let response = String(data: data, encoding: .utf8) {
                
                if response == "COMPASS CALIBRATED" {
                    compass_calibrated = true
                    alignmentIsFinished = true
                }
            }
        }

        if characteristic.uuid == ESP32FernsteuerCharUUID {
            if let data = characteristic.value,
                let response = String(data: data, encoding: .utf8)
            {
                if response == "DATA RECEIVED" {
                    data_received = true
                } else if response == "AT STARTPOSITION" {
                    at_startposition = true
                } else if response == "TRACK END" {
                    data_received = false
                    at_startposition = false
                    start_gesendet = false
                    anzahl_gesendete_bytes = 0
                    anzahl_zusendende_bytes = 0
                    
                } else if response.hasPrefix("ACC: ") {
                    let acc = Int(response.split(separator: " ").last!) ?? 0
                    if acc == 0 {
                        accuracyIMU = .zero
                    } else if acc == 1 {
                        accuracyIMU = .one
                    } else if acc == 2 {
                        accuracyIMU = .two
                    } else if acc == 3 {
                        accuracyIMU = .three
                    }
                } else if response.hasPrefix("AP:") {
                    let substring = response.components(separatedBy: " ")
                    guard substring.count == 3 else { return }
                    akt_azimuth = Float(substring[1]) ?? 0.0
                    akt_elevation = Float(substring[2]) ?? 0.0

                } else if response == "PASS FIN" {
                    reset_connection()
                }
            }

        }
        
        else if characteristic.uuid == ESP32StatusCharUUID {
//            os_log("STATUS ERHALTEN")
            guard let data = characteristic.value else { return }
//            let response = String(data: data, encoding: .utf8)
//            print(response)
            addMessage(data)
        }
    }

}
