//
//  SatelliteDetailViewModel.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 20.05.25.
//

import Combine
import CoreLocation
import OSLog
import Observation
import SatelliteKit
import SwiftData
import SwiftUI

@Observable
class SatelliteViewModel {
    static let shared = SatelliteViewModel()

    var satellite: SatelliteData_SaveModel?
    var error: String?
    var isLoaded: Bool = false
    var satellitenPosition: AziEleDst?
    var satellitenPositionvorhanden: Bool = false
    var satelleiteID: Int?
    var IphoneAsSensor: Bool = false
    var BNO085AsSensor: Bool = false
    var SensorIsSelected: Bool = false
    var StarteCountdownforIphoneAlignment: Bool = false
    var StarteCountdownforIphoneACC: Bool = false
    var IPhoneIsMounted: Bool = false
    var CountdownIphonePlacement: Int = 20
    var CountdownIphoneAccurary: Int = 20
    var showCountdownDialog: Bool = false
    var wurdeAbbgebrochen: Bool = false

    private var dataManager: DataManager_SatModel?

    private var AbfrageService = TLE_API()
    private var locationManager = LocationManager()
    private var bleManager = myBluetoothService.shared
    private var motionManager = MotionManager()

    private var standortistvorhanden: Bool = false
    var isInitialized: Bool = false
    var firstLoad: Bool = true
    private var cancellables = Set<AnyCancellable>()
    private var cancellables_BLE = Set<AnyCancellable>()

    private var aktuellePosition: AziEleDst = AziEleDst(0, 0, 0)
    private var meinStandort: LatLonAlt = LatLonAlt(0, 0, 0)
    private var satPosition: LatLonAlt = LatLonAlt(0, 0, 0)

    private var azi_speed: Float = 0

    private var data: CommDataType?
    private var hamradioData: AmateurfunkSatellite?
    private var weatherradioData: WeatherSatellite?
    
    private var calTimer: Timer?
    var countdownTimerforIphoneAlignment: Timer?
    var countdownTimerforIphoneAccurary: Timer?
    var AlignmentString: String = ""
    
    

    @AppStorage("LastUpdate") @ObservationIgnored private var lastUpdate: Date?
    @AppStorage("LastUpdateLatitude") @ObservationIgnored private
        var lastUpdateLatitude: Double?
    @AppStorage("LastUpdateLongitude") @ObservationIgnored private
        var lastUpdateLongitude: Double?

    private init() {}

    func initialize(with container: ModelContainer) {
        guard !isInitialized else { return }
        self.dataManager = DataManager_SatModel(modelContainer: container)
        self.standortistvorhanden = getlocation()
        self.startUpdates()
        self.isInitialized = true
        
        bleManager.$peripheralConnectionStatusforSubscriptions
            .compactMap { $0 } // Nur non-nil Werte
            .sink { [weak self] data in
                self?.handleConnStatusChange(data)
                }
            .store(in: &cancellables_BLE)
        
        }
    
    private func handleConnStatusChange(_ status: connectionStatus) {
        if status == .disconnected {
            IphoneAsSensor = false
            BNO085AsSensor = false
            SensorIsSelected = false
        }
    }

    private func startUpdates() {
        locationManager.$locationData
            .first()
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self = self else { return }
                Task {
                    await self.updateInfosForAllSats()
                }

            }
            .store(in: &cancellables)
    }

    func triggerInitalUpdatePasses() {
        if standortistvorhanden {
            startUpdates()
        }
    }

    func selectSatellite(for SatID: Int) {
        print("Sat is selected!")
        self.satelleiteID = SatID
    }

    func returnSatID() -> Int? {
        return self.satelleiteID
    }

    private func getlocation() -> Bool {
        locationManager.checkLocationAuthorization()

        guard let standort = locationManager.lastKnownLocation,
            let altitude = locationManager.altitude
        else {
            os_log("kein Standort vorhanden!")
            return false
        }

        meinStandort = LatLonAlt(
            standort.latitude,
            standort.longitude,
            altitude
        )

        standortistvorhanden = true

        return true

    }

    func updateTLEData(for SatID: Int) async {
        do {
            let (tle_vorhanden, _, _) = try await AbfrageService.getTLE(
                noradID: SatID
            )
            if tle_vorhanden {
                let tledata = AbfrageService.extractTLEdata()
                guard self.isInitialized else {
                    return
                }
                _ = try await dataManager!.updateTLE(
                    SatID: SatID,
                    tleData: tledata
                )
            }
        } catch {
            os_log("TLE Download fehlgeschlagen")
        }
    }

    func returnPasses(for SatID: Int) async -> [NextPassesData]? {
        guard self.isInitialized else {
            return nil
        }
        do {
            let passes = try await dataManager!.loadPasses(SatID: SatID)
            return passes
        } catch {
            os_log("Konnte keine Überflugdaten abrufen!")
            return nil
        }

    }

    func saveCommData(for SatID: Int, TypeofSat: CommDataType?) async -> Bool {
        guard TypeofSat != nil else {
            return false
        }

        data = TypeofSat!

        switch data {
        case .hamSat(let asdf):

            hamradioData = asdf

            if hamradioData!.transponderArt == .uv_inv
                || hamradioData!.transponderArt == .vu_inv
            {
                hamradioData!.isInverting = true
            }

            do {
                let status = try await dataManager!.saveHamCommData(
                    SatID: SatID,
                    hamSatFreq: hamradioData!
                )
                return status
            } catch {
                return false
            }

        case .weatherSat(weatherradioData):
            return true
        case .none:
            return false
        case .some(_):
            return false
        }

    }

    func updateSatName(for SatID: Int, name: String) async -> Bool {
        do {
            let status = try await dataManager!.updateSatName(
                SatID: SatID,
                name: name
            )
            return status
        } catch {
            return false
        }
    }

    func updatePasses(for SatID: Int) async -> Bool {
        if !standortistvorhanden {
            _ = getlocation()
        }

        guard self.isInitialized else {
            return false
        }
        
        do {
            let nextPasses = try await AbfrageService.getnextPasses(
                noradID: SatID,
                latitude: meinStandort.lat,
                longitude: meinStandort.lon,
                altitude: meinStandort.alt,
                days: 1,
                elevation: 10
            )

            let passUpdateStatus = try await dataManager!.updatePasses(
                SatID: SatID,
                passes: nextPasses
            )
            return passUpdateStatus
        } catch {
            os_log("Überflug Download fehlgeschlagen")
            return false
        }
    }

    func haversine_distance(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let R = 6371.009
        let rad_con_factor = 3.14159 / 180.0

        let dLat = (lat2 - lat1) * rad_con_factor
        let dLon = (lon2 - lon1) * rad_con_factor
        let lat1Rad = lat1 * rad_con_factor
        let lat2Rad = lat2 * rad_con_factor                    

        let a =
            sin(dLat / 2) * sin(dLat / 2) + cos(lat1Rad) * cos(lat2Rad)
            * sin(dLon / 2) * sin(dLon / 2)

        return R * a
    }

    func updateInfosForAllSats() async -> Bool {

        var outcome: Bool = false
        var updatenötig: Bool = false

        if lastUpdate == nil {
            lastUpdate = Date()
        }

        if !standortistvorhanden {
            _ = getlocation()
        }

        if lastUpdateLatitude == nil {
            lastUpdateLatitude = meinStandort.lat
            lastUpdateLongitude = meinStandort.lon
        }

        let distanceSinceLastUpdate: Double = haversine_distance(
            lat1: lastUpdateLatitude!,
            lon1: lastUpdateLongitude!,
            lat2: meinStandort.lat,
            lon2: meinStandort.lon
        )
        
        

        let intervalsinceLastUpdate = Date().timeIntervalSince(lastUpdate!)
        //        print(intervalsinceLastUpdate)

        if distanceSinceLastUpdate > 10 || intervalsinceLastUpdate > (21600/4) {
            updatenötig = true

        }

        guard self.isInitialized, updatenötig else {
            return false
        }
        do {
            let satIDs = try await dataManager!.loadAllSatellites()

            for satIDfetch in satIDs {
                outcome = await updatePasses(for: satIDfetch)
                await updateTLEData(for: satIDfetch)
                if !outcome {
                    return false
                }

            }

            lastUpdate = Date()
            lastUpdateLatitude = meinStandort.lat
            lastUpdateLongitude = meinStandort.lon

            updatenötig = false

            return true

        } catch {
            return false
        }
    }

    func removeOldPasses(for SatID: Int) async {
        do {
            _ = try await dataManager!.removeOutdatedPasses(SatID: SatID)
        } catch {
            os_log("Fehler beim Löschen alter Überflugdaten")
        }
    }

    @MainActor
    func sgp4Update(for SatID: Int, inputDate: Date) async -> AziEleDst? {
        if !standortistvorhanden {
            _ = getlocation()
        }

        guard standortistvorhanden else {
            return nil
        }

        guard isInitialized else {
            return nil
        }

        do {
            guard
                let (sat_name, sat_tleLine1, sat_tleLine2) = try await
                    dataManager!.returnTLELines(SatID: SatID)
            else {
                return nil
            }
            let elements = try Elements(sat_name, sat_tleLine1, sat_tleLine2)
            let sat = Satellite(elements: elements)
            let JulInputDate = julianDate(from: inputDate)
            let satPointing = try sat.topPosition(
                julianDays: JulInputDate,
                observer: meinStandort
            )
            return satPointing
        } catch {
            return nil
        }
    }

    func julianDate(from date: Date) -> Double {
        return 2440587.5 + (date.timeIntervalSince1970 / 86400.0)
    }

    @MainActor
    func plotPathofSatellite(for SatID: Int, selectedPass: NextPassesData) async
        -> [AziEleSpeeds]?
    {

        var timeStampArray: [Double] = []
        var positionArray: [AziEleDst] = []
        var positionSpeedArray: [AziEleSpeeds] = []
        var x = selectedPass.startUTC
        var y = selectedPass.endUTC
        var freq_144: Double?
        var freq_430: Double?
        while x < y {
            timeStampArray.append(Double(x))
            //            os_log("\(x)")
            x += 0.5

        }
        do {
            (freq_144, freq_430) = try await dataManager!.loadFrequencies(
                SatID: SatID
            )
        } catch {
            (freq_144, freq_430) = (144000.0, 430000.0)
        }

        for timestamp in timeStampArray {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let position = await sgp4Update(for: SatID, inputDate: date)
            if position != nil {
                positionArray.append(position!)
            } else {
                print("keine Position!")
            }
        }

        let date = Date(
            timeIntervalSince1970: TimeInterval(selectedPass.endUTC)
        )
        let position = await sgp4Update(for: SatID, inputDate: date)
        if position != nil {
            positionArray.append(position!)
        } else {
            print("keine Position!")
        }

        guard standortistvorhanden else {
            return nil
        }

        let grenze = positionArray.count - 1

        for x in 0..<grenze {
            azi_speed = Float(positionArray[x + 1].azim - positionArray[x].azim)
            let speed = (positionArray[x + 1].dist - positionArray[x].dist) * 2

            let dop_144 = (speed / 299792.4580) * (freq_144 ?? 144000.0)
            let dop_430 = (speed / 299792.4580) * (freq_430 ?? 435000.0)

            if azi_speed < -45.0 {
                print("Hier war es kleiner als 90 Grad pro Sekunde")
                let azi_0 = positionArray[x + 1].azim + 360.0
                azi_speed = Float(azi_0 - positionArray[x].azim)
            } else if azi_speed > 45.0 {
                print("Hier war es größer als 90 Grad pro Sekunde")
                let azi_1 = positionArray[x + 1].azim - 360.0
                azi_speed = Float(azi_1 - positionArray[x].azim)
            }

            let temp = AziEleSpeeds(
                id: UUID(),
                azimuth: Float(positionArray[x].azim),
                elevation: Float(positionArray[x].elev),
                azi_speed: azi_speed,
                ele_speed: Float(
                    positionArray[x + 1].elev - positionArray[x].elev
                ),
                doppler_144: Float(dop_144),
                doppler_430: Float(dop_430)
            )
            
//            print(temp)
            positionSpeedArray.append(temp)

        }

        return positionSpeedArray
    }

    func loadPassesforOverview() async -> [PassDataforOverview]? {
        var passes: [PassDataforOverview] = []

        guard self.isInitialized else {
            print("Ich fliege hier raus!")
            return nil

        }

        do {
            let satIDs = try await dataManager?.loadAllSatellites()
            print(satIDs ?? 0)

            for satIDfetch in satIDs! {
                //                print("Ich schaffe es zum \(satIDfetch)")
                let passesSat = await returnPasses(for: satIDfetch)
                let (satName, satType) = try await dataManager!
                    .returnSatDataforOverview(for: satIDfetch)

                guard satName != nil else {

                    return nil
                }

                for passSat in passesSat! {
                    passes.append(
                        PassDataforOverview(
                            pass: passSat,
                            satelliteName: satName!,
                            SatID: satIDfetch,
                            satelliteType: satType ?? SatelliteType.undefiniert
                        )
                    )
                }

            }

        } catch {
            return nil
        }

//        print("Juhu")
        passes.sort(by: { $0.startTime < $1.startTime })

        return passes
    }

    func preparePassDataforTransmission(passData: [AziEleSpeeds]) -> [Data] {
        var x = 0
        var floatData: [Float] = []
        var batchData = Data()
        var batechesData: [Data] = []

        for pass in passData {
            floatData = [pass.azimuth, pass.azi_speed, pass.elevation, pass.ele_speed]

            for floatValue in floatData {
                let floatByte = withUnsafeBytes(of: floatValue) { Data($0) }
                batchData.append(contentsOf: floatByte)
            }
            floatData = []
            x += 1

            if x == 16 {
                x = 0
                batechesData.append(batchData)
                batchData = Data()
            }
        }

        if x < 16 {
            floatData = [passData.last!.azimuth, 0.0, passData.last!.elevation, 0.0]
            while x < 16 {
                for floatValue in floatData {
                    let floatByte = withUnsafeBytes(of: floatValue) { Data($0) }
                    batchData.append(contentsOf: floatByte)
                }
                
                x += 1
            }
            batechesData.append(batchData)
        }

        return batechesData
    }
    
    func startCountdownTimer() {
        countdownTimerforIphoneAlignment = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.CountdownIphonePlacement -= 1
            
            if self.CountdownIphonePlacement == 0 {
                self.stopCountdownTimer()
            }
        }
    }
    
    func stopCountdownTimer() {
        countdownTimerforIphoneAlignment?.invalidate()
        countdownTimerforIphoneAlignment = nil
        StarteCountdownforIphoneAlignment = false
        showCountdownDialog = false
        CountdownIphonePlacement = 20
        if (!wurdeAbbgebrochen) {
            startAlignment()
        }
    }
    
    func startCountdownTimerAcc() {
        motionManager.startAlignment()
        countdownTimerforIphoneAccurary = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.CountdownIphoneAccurary -= 1
            
            if self.CountdownIphoneAccurary == 0 {
                self.stopCountdownTimerAcc()
            }
        }
    }
    
    func stopCountdownTimerAcc() {
        CountdownIphoneAccurary = 20
        StarteCountdownforIphoneACC = false
        countdownTimerforIphoneAccurary?.invalidate()
        countdownTimerforIphoneAccurary = nil
        
        if (!wurdeAbbgebrochen) {
            StarteCountdownforIphoneAlignment = true
            startCountdownTimer()
        }
    }
    
    func startAlignment() {
        print("Klappt!")
        
        calTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.doAlignment()
        }
    }
    
    func doAlignment() {
        //print("Ich werde auch aufgerufen!")
        
        var batchData = Data()
        
        
        guard let heading = motionManager.azimuth, let elevation = motionManager.elevation else {
            print("Keine neuen Sensordaten verfügbar!")
            return
        }
        let heading_float = Float(heading)
        let elevation_float = Float(elevation)

        let floatByte = withUnsafeBytes(of: heading_float) { Data($0) }
        batchData.append(contentsOf: floatByte)
        
        let floatByte1 = withUnsafeBytes(of: elevation_float) { Data($0) }
        batchData.append(contentsOf: floatByte1)
        
        bleManager.writeCommand(
            batchData,
            ESPChar: "Align"
        )
        
        bleManager.processWriteQueue()
        
        if bleManager.alignmentIsFinished {
            stopAlignment()
        }
    }
    
    func stopAlignment() {
        motionManager.stopAlignment()
        calTimer?.invalidate()
        calTimer = nil
    }
    
    func selectSensor() {
        
        wurdeAbbgebrochen = false
        guard bleManager.peripheralConnectionStatus == .connected else {
            print("Ich fliege hier raus!")
            return
        }
        
        if IphoneAsSensor {
            print("Iphone wird gesendet")
            let dataString = "SSFO:IPhone"
            let data_comm = dataString.data(using: .utf8)!
            
            bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
            bleManager.processWriteQueue()
            
            SensorIsSelected = true
            
        } else if BNO085AsSensor {
            print("Bno085 wird gesendet")
            let dataString = "SSFO:BNO085"
            let data_comm = dataString.data(using: .utf8)!
            
            bleManager.writeCommand(data_comm, ESPChar: ESPCharStatus.fernsteuer.string)
            bleManager.processWriteQueue()
            
            SensorIsSelected = true
            
        }
    }
    
    func calibrateAndAlign() {
        wurdeAbbgebrochen = false
        guard SensorIsSelected else {
            return
        }
        
        let dataString = "CALIBRATE"
        let data_comm = dataString.data(using: .utf8)!
        bleManager.writeCommand(
            data_comm,
            ESPChar: ESPCharStatus.fernsteuer.string
        )
        bleManager.processWriteQueue()
        
        if IphoneAsSensor {
            StarteCountdownforIphoneACC = true
            showCountdownDialog = true
            startCountdownTimerAcc()
        }
    }
}

extension Date {
    var dayMonthHourMinute: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM. HH:mm"
        dateFormatter.locale = Locale(identifier: "de_DE")

        return dateFormatter.string(from: self)
    }
}
