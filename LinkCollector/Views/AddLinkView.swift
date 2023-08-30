//
//  AddLinkView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI

struct AddLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var favicon: Data?
    @State private var note: String = ""
    @State private var tags = [TagEntity]()

    @State private var urlUpdated = false
    @State private var showProgress = false
    @State private var showAlert = false
    @State private var message = ""
    @State private var addNewTag = false
    
    private var htmlParser = HTMLParser()
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                addLinkButtons()
                addLinkForm()
            }
            
            ProgressView()
                .opacity(self.showProgress ? 1.0 : 0.0)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Unable to connect"),
                  message: Text(message),
                  dismissButton: .default(Text("Dismiss")))
        }
    }
    
    private func addLinkForm() -> some View {
        Form {
            Section(header: Label("URL", systemImage: "link")) {
                TextField("Insert url", text: $url, onCommit: {
                    Task {
                        await updateURL()
                        urlUpdated = true
                        viewModel.userLocality = await viewModel.lookUpCurrentLocation()
                    }
                })
                .autocapitalization(.none)
            }
            
            Section(header: TitleLabel(title: "Title")) {
                TextField("Insert title", text: $title)
            }
            
            Section(header: LocationLabel(title: "Location")) {
                Text("\(viewModel.userLocality)")
            }
            
            Section(header: NoteLabel(title: "Note")) {
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
                dismiss.callAsFunction()
            },
            label: {
                Label("Cancel", systemImage: "chevron.backward")
                    .foregroundColor(.blue)
            })
            
            Spacer()
            
            Text("Add a new link")
            
            Spacer()
            
            Button(action: {
                saveLinkAndTags()
                dismiss.callAsFunction()
            },
            label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .foregroundColor(.blue)
            })
        }
    }
    
    private func updateURL() async {
        let (correctedURL, result) = await viewModel.process(urlString: url)
        
        guard let result = result, !result.isEmpty else {
            self.showProgress = false
            self.message = "Cannot open the given url. Please check if a web browser can open it."
            self.showAlert = true
            return
        }
        
        if let correctedURL = correctedURL, self.url != correctedURL.absoluteString {
            self.url = correctedURL.absoluteString
        }
        
        self.title = result
        self.showProgress = false
        
        if let url = URL(string: self.url) {
            let data = await viewModel.findFavicon(url: url)
            guard let data = data else {
                self.showProgress = false
                self.message = "Cannot open the given url. Please check if a web browser can open it."
                self.showAlert = true
                return
            }
            self.favicon = data
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
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    private func tagSection() -> some View {
        #if targetEnvironment(macCatalyst)
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
                ForEach(self.tags, id: \.self) { tag in
                    TagLabel(title: tag.name ?? "")
                }
            }
        }
        .sheet(isPresented: $addNewTag) {
            AddTagView(tags: $tags)
                .environmentObject(viewModel)
        }
        #else
        List {
            ForEach(self.tags, id: \.self) { tag in
                TagLabel(title: tag.name ?? "")
            }
        }
        .frame(minHeight: bodyTextHeight * CGFloat(self.tags.count))
        .listStyle(InsetListStyle())
        .sheet(isPresented: $addNewTag) {
            AddTagView(tags: $tags)
                .environmentObject(viewModel)
        }
        #endif
    }
    
    private func saveLinkAndTags() -> Void {
        viewModel.saveLinkAndTags(title: title, url: url, favicon: favicon, note: note, latitude: viewModel.userLatitude, longitude: viewModel.userLongitude, locality: viewModel.userLocality, tags: tags)
    }
    
}
