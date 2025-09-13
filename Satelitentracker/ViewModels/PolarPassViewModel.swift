//
//  PolarPassViewModel.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 28.05.25.
//

import Foundation
import SwiftUI
import SatelliteKit

class PolarPassViewModel: ObservableObject {
    
    @Environment(SatelliteViewModel.self) private var SatVM
    
    func drawPolarGrid(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height)/2 - 65
        let elevationRings = [90.0,80.0, 60.0, 30.0, 0.0]
        
        for elevation in elevationRings {
            let ringRadius = radius * (1.0 - elevation/90.0)
            let rect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
            
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.gray.opacity(0.5)),
                lineWidth: 1
            )
        }
        
        for azimuth in stride(from: 0, to: 360, by: 30) {
            let radians = Double(azimuth) * 3.1415962 / 180
            let endX = center.x + radius * sin(radians)
            let endY = center.y - radius * cos(radians) // Y invertiert für korrekte Darstellung
            
            var path = Path()
            path.move(to: center)
            path.addLine(to: CGPoint(x: endX, y: endY))
            
            context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 1)
            
            // Azimut-Labels
            let labelDistance = radius + 25
            let labelX = center.x + labelDistance * sin(radians)
            let labelY = center.y - labelDistance * cos(radians)
            
            context.draw(
                Text("\(Int(azimuth))°"),
                at: CGPoint(x: labelX, y: labelY),
                anchor: .center
            )
        }
    }
    
    func drawPath(context: GraphicsContext, size: CGSize, positionArrayPass: [AziEleSpeeds]) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height)/2 - 65
        
        var path = Path()
        var PassKartesianArray: [CGPoint] = []
        
        for position in positionArrayPass {
            PassKartesianArray.append(convertToKartesians(azimut: Double(position.azimuth), elevation: Double(position.elevation), center: center, radius: radius))
            
        }
        
        path.move(to: PassKartesianArray[0])
        
        for i in 1..<PassKartesianArray.count {
            path.addLine(to: PassKartesianArray[i])
        }
                
        context.stroke(path, with: .color(.red), lineWidth: 2)
        
        context.draw(Text("AOS"), at: PassKartesianArray.first!)
        context.draw(Text("LOS"), at: PassKartesianArray.last!)
        
        
    }
    
    private func convertToKartesians(azimut: Double, elevation: Double, center: CGPoint, radius: Double) -> CGPoint {
        let r_maxElevation = radius * (1 - (elevation/90.0))
        
        let azimut_rad = azimut * 3.1415962 / 180
        let elevation_rad = elevation * 3.1415962 / 180
        
        let x = center.x + r_maxElevation * sin(azimut_rad)
        let y = center.y - r_maxElevation * cos(azimut_rad)
        
        return CGPoint(x: x, y: y)
    }
    
    private func calculatePass() {
        guard SatVM.isLoaded else {
            return
        }
        
        
        
    }
    
}

