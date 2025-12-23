//
//  ContentView.swift
//  MyLocationApp
//
//  Created by Nathan Cho on 12/23/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.0739, longitude: -118.2400),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var locationName: String = "Los Angeles, United States"
    @Published var antipodeLocationName: String = "Indian Ocean"
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func setRandomLocation() {
        let randomLat = Double.random(in: -90...90)
        let randomLong = Double.random(in: -180...180)
        let randomLocation = CLLocation(latitude: randomLat, longitude: randomLong)
        
        DispatchQueue.main.async {
            self.location = randomLocation
            self.region = MKCoordinateRegion(
                center: randomLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            self.reverseGeocode(location: randomLocation)
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        // Reverse geocode current location
        Task {
            let request = MKLocalSearch.Request()
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            
            if let result = try? await MKLocalSearch(request: request).start(),
               let item = result.mapItems.first,
               let address = item.address {
                await MainActor.run {
                    self.locationName = address.fullAddress
                }
            }
        }
        
        // Reverse geocode antipodal location
        let antiLat = -location.coordinate.latitude
        let antiLong = location.coordinate.longitude > 0 ? location.coordinate.longitude - 180 : location.coordinate.longitude + 180
        
        Task {
            let request = MKLocalSearch.Request()
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: antiLat, longitude: antiLong),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            
            if let result = try? await MKLocalSearch(request: request).start(),
               let item = result.mapItems.first,
               let address = item.address {
                await MainActor.run {
                    self.antipodeLocationName = address.fullAddress.isEmpty ? "Ocean" : address.fullAddress
                }
            } else {
                await MainActor.run {
                    self.antipodeLocationName = "Ocean"
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        DispatchQueue.main.async {
            self.location = location
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            self.reverseGeocode(location: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 8)
            
            // Top half: Map in card
            Map(position: .constant(.region(locationManager.region))) {
                if let location = locationManager.location {
                    Annotation("My Location", coordinate: location.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            
            // Bottom half: Controls and Info
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button(action: {
                        locationManager.requestLocation()
                    }) {
                        Text("Current Location")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        locationManager.setRandomLocation()
                    }) {
                        Image(systemName: "dice")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.gray)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    let currentLat = locationManager.location?.coordinate.latitude ?? 34.0739
                    let currentLong = locationManager.location?.coordinate.longitude ?? -118.2400
                    
                    Text(locationManager.locationName)
                        .font(.headline)
                    Text("Latitude: \(currentLat)")
                        .font(.system(.body, design: .monospaced))
                    Text("Longitude: \(currentLong)")
                        .font(.system(.body, design: .monospaced))
                    Text("Current time: \(Date().formatted(date: .omitted, time: .shortened))")
                        .font(.system(.body, design: .monospaced))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Antipodal Point Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Antipodal Point")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        let currentLat = locationManager.location?.coordinate.latitude ?? 34.0739
                        let currentLong = locationManager.location?.coordinate.longitude ?? -118.2400
                        let antiLat = -currentLat
                        let antiLong = currentLong > 0 ? currentLong - 180 : currentLong + 180
                        
                        // Circular map preview
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: antiLat,
                                longitude: antiLong
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                        )))) {
                            Annotation("", coordinate: CLLocationCoordinate2D(
                                latitude: antiLat,
                                longitude: antiLong
                            )) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(locationManager.antipodeLocationName)
                                .font(.system(.body, design: .monospaced))
                                .bold()
                            Text("Latitude: \(antiLat)")
                                .font(.system(.body, design: .monospaced))
                            Text("Longitude: \(antiLong)")
                                .font(.system(.body, design: .monospaced))
                            Text("Current time: \(Date().formatted(date: .omitted, time: .shortened))")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                    }
                    
                    Text("Most land points are opposite to ocean. Only a few places like parts of South America and Spain have land antipodes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
            .frame(maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
