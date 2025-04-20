//
//  MapView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/24/20.
//

import SwiftUI
import MapKit

struct AnnotationItem: Identifiable {
    let id = UUID()
    var location: CLLocationCoordinate2D
}

struct MapView: View {
    var location: CLLocationCoordinate2D
    
    @State private var region = MKCoordinateRegion()
       
    var body: some View {
        Map(initialPosition: MapCameraPosition.region($region.wrappedValue), bounds: MapCameraBounds(centerCoordinateBounds: $region.wrappedValue), interactionModes: .zoom) {
            UserAnnotation()
            
            Marker("", coordinate: location)
        }
        .onAppear {
            setRegion(location)
        }
    }
    
    private func setRegion(_ location: CLLocationCoordinate2D) -> Void {
        region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    }
}
