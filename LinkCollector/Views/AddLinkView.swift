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
    @State private var note: String = ""
    @State private var tags = [String]()
    @State private var titleCandidates = [Title]()
    @State private var titleCandidate = Title(text: "")
    
    @State private var urlUpdated = false
    
    @State private var showProgress = false
    @State private var addNewTag = false
    
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
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
                            linkCollectorViewModel.lookUpCurrentLocation()
                        })
                        .autocapitalization(.none)
                    }
                    
                    Section(header: Text("Title")) {
                        TextField("Insert title", text: $title)
                            .autocapitalization(.sentences)
                    }
                    
                    Section(header: Text("Location"), content: {
                        Text("Location: \(linkCollectorViewModel.userLocality)")
                    })
                    
                    Section(header: Text("Note")) {
                        TextField("Insert note", text: $note)
                    }
                    
                    Section(header: Text("Tags")) {
                        Button {
                            addNewTag.toggle()
                        } label: {
                            Label("Add tags", systemImage: "tag")
                        }
                        
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
                                ForEach(self.tags, id: \.self) { tag in
                                    Button {
                                        print("\(tag)")
                                    } label: {
                                        Text(tag)
                                    }
                                }
                            }
                        }
                        .sheet(isPresented: $addNewTag) {
                            AddTagView(tags: $tags)
                                .environment(\.managedObjectContext, viewContext)
                                .environmentObject(linkCollectorViewModel)
                        }
                    }
                }
                
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    },
                    label: {
                        HStack {
                            Label("Cancel", systemImage: "chevron.backward")
                        }
                    })
                    
                    Spacer()
                    
                    Button(action: {
                        let linkEntity = LinkEntity.create(title: title, url: url, note: note, latitude: linkCollectorViewModel.userLatitude, longitude: linkCollectorViewModel.userLongitude, context: viewContext)
                        
                        let linkDTO = LinkDTO(id: linkEntity.id ?? UUID(), title: linkEntity.title ?? "", note: linkEntity.note ?? "")
                        
                        for tag in tags {
                            linkCollectorViewModel.tagDTO = TagDTO(name: tag, link: linkDTO)
                        }
                        
                        presentationMode.wrappedValue.dismiss()
                    },
                    label: {
                        HStack {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                    })
                }
               
            }
            .navigationBarTitle("Add Link")
            
            ProgressView().opacity(self.showProgress ? 1.0 : 0.0)
        }
        .padding()
        
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
