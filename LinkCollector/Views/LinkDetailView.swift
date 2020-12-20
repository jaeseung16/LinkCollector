//
//  LinkDetailView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI

struct LinkDetailView: View {
    let entity: LinkEntity!
    
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    var body: some View {
        ScrollView {
            VStack {
                entity.created.map {
                    Text(dateFormatter.string(from: $0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                entity.url.map {
                    Link(entity.title ?? "link", destination: $0)
                }
                
            }
            .multilineTextAlignment(.center)
            .padding()
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
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
