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
        Map(coordinateRegion: $region, annotationItems: [AnnotationItem(location: location)]) { item in
            MapPin(coordinate: item.location)
        }
        .onAppear {
            setRegion(location)
        }
    }
    
    private func setRegion(_ location: CLLocationCoordinate2D) -> Void {
        region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(location: CLLocationCoordinate2D())
    }
}
