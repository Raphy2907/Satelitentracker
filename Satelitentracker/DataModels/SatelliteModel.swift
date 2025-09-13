//
//  SatelliteModel.swift/Volumes/T7/Swift_Projects/Satelitentracker/Satelitentracker/N2YoService.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 24.04.25.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI

struct TLE_Data: Codable {
    var tle_line1: String
    var tle_line2: String
    var name: String

    var epoch_year: Int
    var epoch_days: Double
    var widerstandskoeff_sgp: Double
    var widerstandskoeff_sgp4: Double
    var inklination: Double
    var raan: Double
    var excentricity: Double
    var argofperigee: Double
    var mittlereanomalie: Double
    var mittlerebewegung: Double
    var nummerumlauf: Double

}

enum SatelliteType: String, Codable, CaseIterable {
    case weatherSat = "weatherSat"
    case hamSat = "hamSat"
    case undefiniert = "undefiniert"
    
    var displayName: String {
        switch self {
        case .weatherSat: return "Wettersatellit"
        case .hamSat: return "Amateurfunksatellit"
        case .undefiniert: return "Kein Typ ausgewählt"
        }
    }
}

enum CommDataType {
    case hamSat(AmateurfunkSatellite)
    case weatherSat(WeatherSatellite)
}

enum TransponderType: String, Codable, CaseIterable {
    case fm = "FM"
    case vu = "VU"
    case uv = "UV"
    case vu_inv = "VU Invertiert"
    case uv_inv = "UV Invertiert"
    
    var displayName: String {
        switch self {
        case .fm: return "FM"
        case .vu: return "VHF Uplink UHF Downlink"
        case .uv: return "UHF Uplink VHF Downlink"
        case .vu_inv: return "VHF Uplink UHF Downlink Invertiert"
        case .uv_inv: return "UHF Uplink VHF Downlink Invertiert"
        }
    }
}

struct WeatherSatellite: Codable, Identifiable, Equatable {
    var id = UUID()
    var downlink_freq: Double
    var modulation: String
}

struct AmateurfunkSatellite: Codable, Identifiable, Equatable {
    var id = UUID()
    var uplink_freq: Double
    var downlink_freq: Double
    var modulation: String
    var transponderArt: TransponderType
    var bandbreite: Double?
    var isInverting: Bool = false
    var isActive: Bool = false
    
    var telemetry_freq: Double?
    var telemetry_mode: String?
    
    var cw_bake_freq: Double?
    
    init(uplink_freq: Double, downlink_freq: Double, transponderArt: TransponderType) {
        self.uplink_freq = uplink_freq
        self.downlink_freq = downlink_freq
        self.modulation = ""
        self.transponderArt = transponderArt
    }
}

struct PassDataforOverview {
    let pass: NextPassesData
    let satelliteName: String
    let SatID: Int
    let satelliteType: SatelliteType?
    
    var startTime: Date {
        return Date(timeIntervalSince1970: pass.startUTC)
    }
    
    var endTime: Date {
        return Date(timeIntervalSince1970: pass.endUTC)
    }
}


@Model
final class SatelliteData_SaveModel {

    @Attribute(.unique) var id: UUID
    var noradID: Int
    var beschreibung: String?
    var satType: SatelliteType?
    var ausgewaehlt: Bool = false
    var passes_downloaded: Bool = false
    var passes_downloaddate: Date?
    var tle_downloaddate: Date?
    var tle_vorhanden: Bool = false
    var passes_count: Int = 0
    var tle_data: TLE_Data
    var nextPasses: [NextPassesData]? = []
    var AmateurfunkFruequency: AmateurfunkSatellite?

    init(noradID: Int, beschreibung: String?, tle_data: TLE_Data) {
        self.id = UUID()
        self.noradID = noradID
        if let beschreibung {
            self.beschreibung = beschreibung
        }

        self.tle_data = tle_data
    }

}

@ModelActor
actor DataManager_SatModel {

    func loadsatellite(SatID: Int) throws -> SatelliteData_SaveModel? {
        let descriptor = FetchDescriptor<SatelliteData_SaveModel>(
            predicate: #Predicate { sat in
                sat.noradID == SatID
            }
        )

        if let satellite = try modelContext.fetch(descriptor).first {
            return satellite
        } else {
            return nil
        }

    }
    
    func returnSatDataforOverview(for SatID: Int) throws -> (String?, SatelliteType?) {
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return (nil, nil)
        }
        
        return (satellite.tle_data.name, satellite.satType)
        
    }
    
    func loadAllSatellites() throws -> [Int] {
        var list_satIDs: [Int] = []
        let descriptor = FetchDescriptor<SatelliteData_SaveModel>()
        let satellites = try modelContext.fetch(descriptor)
        
        for satellite in satellites {
            list_satIDs.append(satellite.noradID)
        }
        
        return list_satIDs
    }

    func insertNewSatellite(SatID: Int, tle_data: TLE_Data) {
        let satellite = SatelliteData_SaveModel(
            noradID: SatID,
            beschreibung: "",
            tle_data: tle_data
        )
        modelContext.insert(satellite)
    }
    
    func saveHamCommData(SatID: Int, hamSatFreq: AmateurfunkSatellite) throws -> Bool {
        
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return false
        }
        
        satellite.satType = .hamSat
        satellite.AmateurfunkFruequency = hamSatFreq
        
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }
    
    func loadFrequencies(SatID: Int) throws -> (Double?, Double?) {
        
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return (nil, nil)
        }
        
        guard satellite.satType != .hamSat && satellite.AmateurfunkFruequency != nil else {
            return (nil, nil)
        }
        
        if satellite.AmateurfunkFruequency!.downlink_freq > satellite.AmateurfunkFruequency!.uplink_freq {
            return (satellite.AmateurfunkFruequency!.uplink_freq, satellite.AmateurfunkFruequency!.downlink_freq)
        } else {
            return (satellite.AmateurfunkFruequency!.downlink_freq, satellite.AmateurfunkFruequency!.uplink_freq)
        }
        
    }
    
    func updateSatName(SatID: Int, name: String) throws -> Bool {
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return false
        }
        
        satellite.tle_data.name = name
        
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }

    func updateTLE(SatID: Int, tleData: TLE_Data)
        async throws -> Bool
    {
        var temp_tle_data: TLE_Data = tleData
        
        guard let satellite = try loadsatellite(SatID: SatID) else {
            insertNewSatellite(SatID: SatID, tle_data: tleData)
            do {
                try modelContext.save()
                return true
            } catch {
                return false
            }
        }
        
        if satellite.tle_data.name != tleData.name {
            temp_tle_data.name = satellite.tle_data.name
        }

        satellite.tle_data = temp_tle_data
        satellite.tle_downloaddate = Date()

        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }

    }

    func removeOutdatedPasses(SatID: Int) throws -> Bool {
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return false
        }
        
        if let passes = satellite.nextPasses {
            for pass in passes {
                if pass.endUTC < Date().timeIntervalSince1970 {
                    satellite.nextPasses?.removeAll(where: {
                        $0.endUTC == pass.endUTC
                    })
                    satellite.passes_count -= 1
                }
            }
        }

        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }

    func updatePasses(SatID: Int, passes: [NextPassesData]) async throws -> Bool
    {
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return false
        }
        
        
        satellite.nextPasses?.removeAll()

        for pass in passes {
            satellite.nextPasses!.append(pass)
        }

        satellite.passes_count = passes.count
        satellite.passes_downloaded = true
        satellite.passes_downloaddate = Date()
    
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }
    
    func loadPasses(SatID: Int) throws -> [NextPassesData]?
    {
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return nil
        }
        
        let hatgeklappt = try removeOutdatedPasses(SatID: SatID)
        
        if hatgeklappt {
            return satellite.nextPasses
        } else {
            return nil
        }
        
    }
    
    func returnTLELines(SatID: Int) throws -> (String, String, String)?
    {
        guard let satellite = try loadsatellite(SatID: SatID) else {
            return nil
        }
        
        return (satellite.tle_data.name, satellite.tle_data.tle_line1, satellite.tle_data.tle_line2)
    }
    
}

