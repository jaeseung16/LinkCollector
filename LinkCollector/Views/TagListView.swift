//
//  TagListView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/4/25.
//

import SwiftUI

struct TagListView: View {
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @State private var showAlert = false
    @State private var message = ""
    @Binding var selectedTag: TagEntity?
    
    var body: some View {
        GeometryReader { geometry in
            List(selection: $selectedTag) {
                ForEach(viewModel.tags) { tag in
                    if let name = tag.name {
                        NavigationLink(value: tag) {
                            TagLabel(title: name)
                                .foregroundStyle((tag.links?.count ?? 0) > 0 ? .primary : .secondary)
                        }
                    } else {
                        NavigationLink(value: tag) {
                            TagLabel(title: "Tag without name")
                                .foregroundStyle((tag.links?.count ?? 0) > 0 ? .primary : .secondary)
                        }
                    }
                }
                .onDelete(perform: removeTag)
            }
            #if canImport(UIKit)
            .listStyle(GroupedListStyle())
            #else
            .listStyle(DefaultListStyle())
            #endif
            .alert("Unable to Save Data", isPresented: $showAlert) {
                Button {
                    showAlert.toggle()
                } label: {
                    Text("Dismiss")
                }
            } message: {
                Text(message)
            }
        }
    }
    
    private func removeTag(indexSet: IndexSet) -> Void {
        Task {
            for index in indexSet {
                let tag = viewModel.tags[index]
                viewModel.delete(tag: tag)
            }
        
            do {
                try await viewModel.save()
            } catch {
                message = "Failed to delete the selected tag"
                showAlert = true
            }
            
            viewModel.fetchAll()
        }
    }
}
