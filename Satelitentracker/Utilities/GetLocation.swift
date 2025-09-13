//
//  GetLocation.swift
//  Satelitentracker
//
//  Created by Raphael Schwierz on 27.05.25.
//

import Foundation
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var locationData: CLLocation?
    @Published var altitude: CLLocationDistance?
    @Published var heading: CLLocationDirection?
    @Published var headingAccuracy: CLLocationDirectionAccuracy = 0.0
    var manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func updateLocation() {
        manager.requestLocation()
    }
    
    func startUpdateHeadingforAlignment() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.headingFilter = 0.05
        manager.startUpdatingHeading()
    }
    
    func stopUpdateHeadingforAlignment() {
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.stopUpdatingHeading()
    }
       
       
    func checkLocationAuthorization() {
        
        manager.requestLocation()
        
        switch manager.authorizationStatus {
        case .notDetermined://The user choose allow or denny your app to get the location yet
            manager.requestWhenInUseAuthorization()
            
        case .restricted://The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
            print("Location restricted")
            
        case .denied://The user dennied your app to get location or disabled the services location or the phone is in airplane mode
            print("Location denied")
            
        case .authorizedAlways://This authorization allows you to use all location services and receive location events whether or not your app is in use.
            print("Location authorizedAlways")
            lastKnownLocation = manager.location?.coordinate
            
        case .authorizedWhenInUse://This authorization allows you to use all location services and receive location events only when your app is in use
            print("Location authorized when in use")
            lastKnownLocation = manager.location?.coordinate
            
        @unknown default:
            print("Location service disabled")
            
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {//Trigged every time authorization status changes
        checkLocationAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last?.coordinate
        altitude = locations.last?.ellipsoidalAltitude
        altitude = altitude!*0.001
        locationData = locations.last
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.magneticHeading >= 0 {
            heading = newHeading.trueHeading
        } else {
            heading = newHeading.magneticHeading
        }
        
        headingAccuracy = newHeading.headingAccuracy
        
        print("Heading: \(heading)")
        print("Heading Accuracy: \(headingAccuracy)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error)
    }
}


    
    
    

