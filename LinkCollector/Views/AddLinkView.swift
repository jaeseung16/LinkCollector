//
//  AddLinkView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI

struct AddLinkView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var note: String = ""
    @State private var tags = [String]()

    @State private var urlUpdated = false
    @State private var showProgress = false
    @State private var addNewTag = false
    
    private var htmlParser = HTMLParser()
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                addLinkForm()
                addLinkButtons()
            }
            .navigationBarTitle("Add Link")
            
            ProgressView()
                .opacity(self.showProgress ? 1.0 : 0.0)
        }
        .padding()
    }
    
    private func addLinkForm() -> some View {
        Form {
            Section(header: Label("URL", systemImage: "link")) {
                TextField("Insert url", text: $url, onCommit: {
                    updateURL()
                    urlUpdated = true
                    linkCollectorViewModel.lookUpCurrentLocation()
                })
                .autocapitalization(.none)
            }
            
            Section(header: Label("Title", systemImage: "rectangle.and.text.magnifyingglass")) {
                TextField("Insert title", text: $title)
            }
            
            Section(header: Label("Location", systemImage: "location")) {
                Text("\(linkCollectorViewModel.userLocality)")
            }
            
            Section(header: Label("Note", systemImage: "note")) {
                TextField("Insert note", text: $note)
            }
            
            Section(header: tagSectionHeader()) {
                tagSection()
            }
        }
    }
    
    private func addLinkButtons() -> some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            },
            label: {
                Label("Cancel", systemImage: "chevron.backward")
                    .foregroundColor(.blue)
            })
            
            Spacer()
            
            Button(action: {
                saveLinkAndTags()
                presentationMode.wrappedValue.dismiss()
            },
            label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .foregroundColor(.blue)
            })
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
    
    private func tagSectionHeader() -> some View {
        HStack {
            TagLabel(title: "Tags")
            
            Spacer()
            
            Button {
                addNewTag.toggle()
            } label: {
                Label("Add tags", systemImage: "plus")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func tagSection() -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
                ForEach(self.tags, id: \.self) { tag in
                    TagLabel(title: tag)
                }
            }
        }
        .sheet(isPresented: $addNewTag) {
            AddTagView(tags: $tags)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(linkCollectorViewModel)
        }
    }
    
    private func saveLinkAndTags() -> Void {
        let linkEntity = LinkEntity.create(title: title, url: url, note: note, latitude: linkCollectorViewModel.userLatitude, longitude: linkCollectorViewModel.userLongitude, context: viewContext)
        
        let linkDTO = LinkDTO(id: linkEntity.id ?? UUID(), title: linkEntity.title ?? "", note: linkEntity.note ?? "")
        
        for tag in tags {
            linkCollectorViewModel.tagDTO = TagDTO(name: tag, link: linkDTO)
        }
    }
    
}

struct AddLinkView_Previews: PreviewProvider {
    static var previews: some View {
        AddLinkView()
    }
}
