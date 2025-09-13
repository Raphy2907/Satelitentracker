//
//  CoreMotion.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 07.09.25.
//

import SwiftUI
import CoreMotion

@Observable
final class MotionManager {
    private var motionManager = CMMotionManager()
    
    var elevation: Double?
    var azimuth: Double?
    
    func startAlignment() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.5
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self]  (motion, error) in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                print("Fehler beim Abrufen der Motiondaten: \(error)")
                return
            }
                        
            guard let motion = motion else {
                print("Keine Motiondaten vorhanden!")
                return
            }
            
            let elevationRadians = motion.attitude.pitch
            self.elevation = elevationRadians * 180.0 / .pi
            
            let azimuthRadians = motion.heading
            self.azimuth = azimuthRadians

            
        }
        
    }
    
    func stopAlignment() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    
}
