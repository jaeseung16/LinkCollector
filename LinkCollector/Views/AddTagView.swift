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
    
    @FetchRequest(entity: TagEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \TagEntity.name, ascending: false)]) private var existingTags: FetchedResults<TagEntity>
    
    @State private var tagName = ""
    @State var saveButtonEnabled = false
    
    @Binding var tags: [String]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Label("Done", systemImage: "chevron.backward")
                    })
                    .frame(width: geometry.size.width, alignment: .leading)
                    
                    Text("Add Tags")
                        .frame(width: geometry.size.width, alignment: .center)
                }
                
                
                Divider()
                
                Form {
                    Section(header: Text("Tags to attach")) {
                        LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
                            ForEach(self.tags, id: \.self) { tag in
                                Button {
                                    if let index = self.tags.firstIndex(of: tag) {
                                        tags.remove(at: index)
                                    }
                                } label: {
                                    Text(tag)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Add a new tag")) {
                        TextField("New tag", text: $tagName) { isEditing in
                            print("\(isEditing)")
                        } onCommit: {
                            saveButtonEnabled = true
                        }
                        
                        HStack {
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
                    
                    Section(header: Text("Tags")) {
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
                    }
                }
            }
        }
        .padding()
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
