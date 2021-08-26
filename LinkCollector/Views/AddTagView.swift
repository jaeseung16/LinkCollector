//
//  AddTagView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/19/21.
//

import SwiftUI

struct AddTagView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @FetchRequest(entity: TagEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \TagEntity.name, ascending: true)]) private var existingTags: FetchedResults<TagEntity>
    
    @State private var tagName = ""
    @State var isEditing = false
    @State var saveButtonEnabled = false
    
    @Binding var tags: [String]
    
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
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Label("Done", systemImage: "chevron.backward")
                    .foregroundColor(.blue)
            })
            .frame(width: geometry.size.width, alignment: .leading)
            
            Text("Add Tags")
                .frame(width: geometry.size.width, alignment: .center)
        }
    }
    
    private func tagsToAttach() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
            ForEach(self.tags, id: \.self) { tag in
                ZStack {
                    RoundedRectangle(cornerRadius: 20.0)
                        .foregroundColor(.secondary)
                    
                    Button {
                        if let index = self.tags.firstIndex(of: tag) {
                            tags.remove(at: index)
                        }
                    } label: {
                        Text(tag)
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
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
            ForEach(self.existingTags, id: \.id) { tag in
                if let name = tag.name {
                    Button {
                        if tags.contains(name) {
                            if let index = tags.firstIndex(of: name) {
                                tags.remove(at: index)
                            }
                        } else {
                            tags.append(name)
                        }
                    } label: {
                        Text(tag.name ?? "")
                    }
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
        linkCollectorViewModel.tagDTO = TagDTO(name: tagName)
    }
    
    private func removeTag(indexSet: IndexSet) -> Void {
        for index in indexSet {
            let tag = existingTags[index]
            viewContext.delete(tag)
        }
        
        do {
            try viewContext.save()
        } catch {
            print(error)
        }
    }
}

struct AddTagView_Previews: PreviewProvider {
    @State private static var tags = [String]()
    static var previews: some View {
        AddTagView(tags: $tags)
    }
}
