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
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
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
        VStack(alignment: .center) {
            Form {
                Section(header: Text("Title")) {
                    TextField("Insert title", text: $title)
                        .autocapitalization(.sentences)
                }
                
                Section(header: Text("URL")) {
                    TextField("Insert url", text: $url)
                        .autocapitalization(.none)
                }

                Section(header: Text("Latitude")) {
                    TextField("Insert latitude", text: $latitude)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("Longitude")) {
                    TextField("Insert longitude", text: $longitude)
                        .autocapitalization(.none)
                }
                
            }

            Button(
                action: {
                    LinkEntity.create(title: title, url: url, latitude: latitude, longitude: longitude, context: viewContext)
                    presentationMode.wrappedValue.dismiss()
                },
                label: {
                    HStack {
                        Text("Save Link")
                    }
                }
            )
        }
        .navigationBarTitle("Add Place")
    }
    
}

struct AddLinkView_Previews: PreviewProvider {
    static var previews: some View {
        AddLinkView()
    }
}
