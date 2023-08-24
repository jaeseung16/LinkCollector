//
//  AddTagView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/19/21.
//

import SwiftUI

struct AddTagView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @State private var tagName = ""
    @State var isEditing = false
    @State var saveButtonEnabled = false
    
    @Binding var tags: [TagEntity]
    
    var isUpdate = false
    
    private var filteredTags: [TagEntity] {
        viewModel.tags.filter { !tags.contains($0) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                barItems(in: geometry)
                
                Divider()
                
                sectionHeader(text: "Tags to attach")
                tagsToAttach()
                
                Spacer(minLength: 20.0)
                
                sectionHeaderWithSaveButton(text: "Add a new tag")
                addNewTag()
                    
                Spacer(minLength: 20.0)
                
                sectionHeader(text: "Tags")
                existingTagsListView()
            }
        }
        .padding()
    }
    
    private func barItems(in geometry: GeometryProxy) -> some View {
        ZStack {
            #if targetEnvironment(macCatalyst)
            Button(action: {
                dismiss.callAsFunction()
            }, label: {
                Label("Done", systemImage: "chevron.backward")
                    .foregroundColor(.blue)
            })
            .frame(width: geometry.size.width, alignment: .leading)
            .onHover(perform: { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            })
            #else
            Button(action: {
                dismiss.callAsFunction()
            }, label: {
                Label("Done", systemImage: "chevron.backward")
                    .foregroundColor(.blue)
            })
            .frame(width: geometry.size.width, alignment: .leading)
            #endif
            
            Text(isUpdate ? "Edit Tags" : "Add Tags")
                .frame(width: geometry.size.width, alignment: .center)
        }
    }
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    private func tagsToAttach() -> some View {
        #if targetEnvironment(macCatalyst)
        LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
            ForEach(self.tags, id: \.self) { tag in
                Button {
                    if let index = self.tags.firstIndex(of: tag) {
                        tags.remove(at: index)
                    }
                } label: {
                    TagLabel(title: tag.name ?? "")
                        .foregroundColor(.primary)
                }
            }
        }
        #else
        List {
            ForEach(self.tags, id: \.self) { tag in
                Button {
                    if let index = self.tags.firstIndex(of: tag) {
                        tags.remove(at: index)
                    }
                } label: {
                    TagLabel(title: tag.name ?? "")
                        .foregroundColor(.primary)
                }
            }
        }
        .listStyle(InsetListStyle())
        .frame(height: bodyTextHeight * CGFloat(self.tags.count))
        #endif
    }
    
    private func addNewTag() -> some View {
        TextField("New tag", text: $tagName) { isEditing in
            self.isEditing = isEditing
        } onCommit: {
            saveButtonEnabled = !tagName.isEmpty
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
    }
    
    private func existingTagsListView() -> some View {
        List {
            ForEach(filteredTags, id: \.id) { tag in
                Button {
                    tags.append(tag)
                } label: {
                    TagLabel(title: tag.name ?? "")
                        .foregroundColor(.primary)
                }
            }
            .onDelete(perform: self.removeTag)
        }
        .listStyle(InsetListStyle())
    }
    
    private func sectionHeader(text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func sectionHeaderWithSaveButton(text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                self.save()
            }, label: {
                Label("Save", systemImage: "square.and.arrow.down")
            })
            .disabled(!saveButtonEnabled)
            .foregroundColor(saveButtonEnabled ? Color.blue : Color.gray)
        }
    }
    
    private func save() -> Void {
        viewModel.tagDTO = TagDTO(name: tagName)
    }
    
    private func removeTag(indexSet: IndexSet) -> Void {
        for index in indexSet {
            let tag = filteredTags[index]
            viewModel.delete(tag: tag)
        }
        
        viewModel.saveContext { error in
            print("\(error.localizedDescription)")
        }
    }
}

