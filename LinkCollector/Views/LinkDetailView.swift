//
//  LinkDetailView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI

struct LinkDetailView: View {
    let url: URL?
    let longitude: Double?
    let latitude: Double?
    let created: Date?
    
    var body: some View {
        ScrollView {
            VStack {
                created.map {
                    Text("\($0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                url.map {
                    Text("\($0)")
                        .font(.body)
                }
                latitude.map {
                    Text("\($0)")
                        .font(.body)
                }
                longitude.map {
                    Text("\($0)")
                        .font(.body)
                }
            }
            .multilineTextAlignment(.center)
            .padding()
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
    }
}

struct LinkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LinkDetailView(url: URL(string: "http://www.google.com"), longitude: 37.751, latitude: -97.822, created: Date())
    }
}
