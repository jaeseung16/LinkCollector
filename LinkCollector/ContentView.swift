//
//  ContentView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import SwiftUI

struct ContentView: View {
    @FetchRequest(entity: LinkEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \LinkEntity.created, ascending: false)]) private var links: FetchedResults<LinkEntity>
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                List {
                    ForEach(links, id: \.id) { link in
                        //NavigationLink(destination: makeDetailView(from: link)) {
                        Link(link.title ?? "", destination: link.url!)
                        //}
                    }
                }
                
                NavigationLink(destination: AddLinkView()) {
                    HStack {
                        Text("Add Link")
                    }
                }
            }
            .navigationBarTitle("Link Collector")
        }
    }
    
    private func makeDetailView(from link: LinkEntity) -> LinkDetailView {
        return LinkDetailView(url: link.url, longitude: link.longitude, latitude: link.latitude, created: link.created)
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
