//
//  AddLinkView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI

struct AddLinkView: View {
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var tags: String = ""
    @State private var titleCandidates = [Title]()
    @State private var titleCandidate = Title(text: "")
    
    @State private var urlUpdated = false
    
    @State private var showProgress = false
    
    @EnvironmentObject var locationViewModel: LocationViewModel
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    var htmlParser = HTMLParser()
    
    var contents: String {
        if let urlURL = URL(string: url) {
            do {
                let contents = try String(contentsOf: urlURL)
                return contents
            } catch {
                return "Cannot download"
            }
        } else {
            return "Invalid url"
        }
    }
    
    var body: some View {
        ZStack {
            
            VStack(alignment: .center) {
                Form {
                    Section(header: Text("URL")) {
                        TextField("Insert url", text: $url, onCommit: {
                            updateURL()
                            urlUpdated = true
                        })
                        .autocapitalization(.none)
                    }

                    /*
                    Section(header: Text("Latitude")) {
                        TextField("Insert latitude", text: $latitude)
                            .autocapitalization(.none)
                    }
                    
                    Section(header: Text("Longitude")) {
                        TextField("Insert longitude", text: $longitude)
                            .autocapitalization(.none)
                    }
                    */
                    
                    Section(header: Text("Tags")) {
                        TextField("Insert tags", text: $tags)
                            .autocapitalization(.none)
                    }
                    
                    Section(header: Text("Title")) {
                        TextField("Insert title", text: $title)
                            .autocapitalization(.sentences)
                    }
                }
                
                VStack {
                    Text("Current Location")
                    Text("Latitude: \(locationViewModel.userLatitude)")
                    Text("Longitude: \(locationViewModel.userLongitude)")
                }
                .foregroundColor(.gray)
                
                Button(
                    action: {
                        LinkEntity.create(title: title, url: url, latitude: locationViewModel.userLatitude, longitude: locationViewModel.userLongitude, context: viewContext)
                        presentationMode.wrappedValue.dismiss()
                    },
                    label: {
                        HStack {
                            Text("Save Link")
                        }
                    }
                )
            }
            .navigationBarTitle("Add Link")
            
            ProgressView().opacity(self.showProgress ? 1.0 : 0.0)
            
        }
        
    }
    
    private func updateURL() {
        showProgress = true
        guard let htmlURL = URL(string: url) else {
            return
        }
       
        htmlParser.parse(url: htmlURL) { result in
            self.title = result
            self.showProgress = false
        }
    }
}

struct AddLinkView_Previews: PreviewProvider {
    static var previews: some View {
        AddLinkView()
    }
}
