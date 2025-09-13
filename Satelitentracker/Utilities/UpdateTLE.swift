//
//  UpdateTLE.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 09.05.25.
//

import Foundation
import SwiftUICore

struct NextPassesData: Codable, Hashable {
    
    var startAz: Double
    var startAzCompass: String
    var startUTC: Double
    var maxAz: Double
    var maxAzCompass: String
    var maxEl: Double
    var maxUTC: Int
    var endAz: Double
    var endAzCompass: String
    var endUTC: Double
    
//    var azimut_nextpassvalues: [Double] = [0]
//    var elevation_nextpassvalues: [Double] = [0]
//    var utc_nextpassvalues: [Int] = [0]
    
}

struct NextPassesIdent: Identifiable {
    var id: UUID
    var nextPassesohneID: NextPassesData
}

struct SatInfoTLE_API:Codable {
    let satid: Int
    let satname: String
    let transactionscount: Int
}

struct SatInfoNextPasses_API:Codable {
    let satid: Int
    let satname: String
    let transactionscount: Int
    let passescount: Int
}

struct ResponseTLE_API:Codable {
    let info: SatInfoTLE_API
    let tle: String
}

struct Response_NextPasses_API:Codable {
    let info: SatInfoNextPasses_API
    let passes: [NextPassesData]
    
}

struct BLEPassData: Codable, Hashable {
    var azimuth: Float
    var elevation: Float
    var azi_speed: Float
    var ele_speed: Float
}

struct BLEPassDataPatch: Codable, Hashable {
    var FourFlooats: [BLEPassData]
}

class TLE_API {
    
    private let apiKey: String = "LE7CXU-3R9S2T-6DTHXN-5GJP"
    private var tle_data: TLE_Data = .init(tle_line1: "", tle_line2: "", name: "", epoch_year: 0, epoch_days: 0.0, widerstandskoeff_sgp: 0.0, widerstandskoeff_sgp4: 0.0, inklination: 0.0, raan: 0.0, excentricity: 0.0, argofperigee: 0.0, mittlereanomalie: 0.0, mittlerebewegung: 0.0, nummerumlauf: 0.0)
    private var NORAD_ID: Int = 0
    private var widsgp4_buffer: Double = 0.0
    private let decoder = JSONDecoder()
    
    func getTLE(noradID: Int) async throws -> (Bool, String, String) {
        NORAD_ID = noradID
        let urlN2YO = "https://api.n2yo.com/rest/v1/satellite/tle/\(NORAD_ID)&apiKey=\(apiKey)"
        var response : ResponseTLE_API = .init(info: .init(satid: 0, satname: "", transactionscount: 0), tle: "")
        
        guard let url = URL(string: urlN2YO) else {
            print("Invalid URL")
            return (false, "", "")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decodedResponse = try? decoder.decode(ResponseTLE_API.self, from: data) {
                response = decodedResponse
            }
            
            let satellitname = response.info.satname
            let tleLines = response.tle.components(separatedBy: CharacterSet.newlines)
                .filter { !$0.isEmpty && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard tleLines.count >= 2 else {
                print("Weniger als zwei TLE Zeilen vorhanden!")
                return (false, "", "")
            }
            tle_data.tle_line1 = tleLines[0]
            tle_data.tle_line2 = tleLines[1]
            tle_data.name = satellitname
            
            return (true, tle_data.tle_line1 , tle_data.tle_line2)
                
        } catch {
            print("Invalid data")
            return (false, "", "")
        }
    }
    
    func extractTLEdata() -> (TLE_Data) {
        
        let elements1 = tle_data.tle_line1.split(separator: " ")
        let elements2 = tle_data.tle_line2.split(separator: " ")
        
        if let epoch_temp = Int(elements1[3].prefix(2)) {
//            print("epoch_temp: \(epoch_temp)")
            if epoch_temp > 56 {
                tle_data.epoch_year = 1900 + epoch_temp
            } else {
                tle_data.epoch_year = 2000 + epoch_temp
            }
        } else {
            tle_data.epoch_year = 0
        }
        
        if let epoch_temp2 = Double(elements1[3].suffix(12)) {
//            print("epoch_temp2: \(epoch_temp2)")
            tle_data.epoch_days  = epoch_temp2
        } else {
            tle_data.epoch_days = 0
        }
        
        if let widsgp4_temp = Double("0." + elements1[6].prefix(5)) {
            widsgp4_buffer = widsgp4_temp
            let exp_widsgp4_temp = Int(elements1[6].suffix(1))
            for _ in 0..<(exp_widsgp4_temp ?? 0) {
                widsgp4_buffer /= 10
            }
            tle_data.widerstandskoeff_sgp4 = widsgp4_buffer
        } else {
            tle_data.widerstandskoeff_sgp4 = 0.0
        }
        
        
        tle_data.inklination = Double(elements2[2]) ?? 0.0
        tle_data.raan = Double(elements2[3]) ?? 0.0
        tle_data.argofperigee = Double(elements2[5]) ?? 0.0
        tle_data.mittlereanomalie = Double(elements2[6]) ?? 0.0
        let temp_eccentricity = "0." + elements2[4]
        tle_data.excentricity = Double(temp_eccentricity) ?? 0.0
        
        
        tle_data.mittlerebewegung = Double(elements2[7].prefix(10)) ?? 0.0
        
        let temp = elements2[7].suffix(6)
        
        tle_data.nummerumlauf = Double(temp.prefix(5)) ?? 0.0
//        print(tle_data)
        return tle_data
        
    }
    
    func getnextPasses(noradID: Int, latitude: Double, longitude: Double, altitude: Double, days: Int, elevation: Int) async throws -> [NextPassesData] {
        
//        var nextPasses: [NextPasses] = []
        var nextPassesID: [NextPassesData] = []
        NORAD_ID = noradID
        let user_lat = String(format: "%.3f", latitude)
        let user_long = String(format: "%.3f", longitude)
        let user_alt = String(format: "%d", Int(altitude))
        let daysStr = String(format: "%d", days)
        let elevationStr = String(format: "%d", elevation)
        var response : Response_NextPasses_API = .init(info: .init(satid: 0, satname: "", transactionscount: 0, passescount: 0), passes: [])
        
        let urlN2YO = "https://api.n2yo.com/rest/v1/satellite/radiopasses/\(NORAD_ID)/\(user_lat)/\(user_long)/\(user_alt)/\(daysStr)/\(elevationStr)/&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlN2YO) else {
            print("Invalid URL")
            return nextPassesID
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decodedResponse = try? decoder.decode(Response_NextPasses_API.self, from: data) {
                response = decodedResponse
            }
           
            
        }
        catch {
                print("Error parsing: \(error)")
        }
        
        for pass in response.passes {
            nextPassesID.append(pass)
        }
        
        return nextPassesID
    }
}
