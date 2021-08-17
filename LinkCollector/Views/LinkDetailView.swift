//
//  LinkDetailView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI
import MapKit

struct LinkDetailView: View {
    let entity: LinkEntity!
    
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    private var location: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: entity.latitude,
            longitude: entity.longitude
        )
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            entity.created.map {
                Text(dateFormatter.string(from: $0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            entity.url.map {
                #if os(macOS)
                Link(entity.title ?? "link", destination: $0)
                    .foregroundColor(.blue)
                    .onHover(perform: { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    })
                #else
                Link(entity.title ?? "link", destination: $0)
                    .foregroundColor(.blue)
                #endif
            }
            
            Divider()
            
            entity.url.map {
                WebView(url: $0)
                    .shadow(color: Color.gray, radius: 1.0)
                    //.border(Color.gray, width: 1.0)
                    .padding()
            }
            
            //MapView(location: location)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LinkDetailView_Previews: PreviewProvider {
    static var linkEntity: LinkEntity {
        let link = LinkEntity()
        link.title = "example"
        link.url = URL(string: "http://www.google.com")
        link.latitude = -97.822
        link.longitude = 37.751
        return link
    }
    
    static var previews: some View {
        LinkDetailView(entity: linkEntity)
    }
}
