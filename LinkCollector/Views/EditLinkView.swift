//
//  EditLinkView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/17/21.
//

import SwiftUI

struct EditLinkView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @State var titleColor = Color.white
    @State var noteColor = Color.white
    
    @State var saveButtonEnabled = false
    
    @State var id: UUID
    @State var title: String
    @State var note: String
    @State var tags: [String]
    @State var editTags = false
    
    @State var titleBeforeEditing = ""
    @State var noteBeforeEditing = ""
    
    @Binding var saveButtonClicked: Bool
    
    @State var originalTags = [String]()
    
    var body: some View {
        VStack {
            editLinkButtons()
            editLinkForm()
        }
        .padding()
    }
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    private func editLinkForm() -> some View {
        Form {
            Section(header: TitleLabel(title: "Title")) {
                TextField("Title", text: $title) { isEditing in
                    if isEditing && titleBeforeEditing == "" {
                        titleBeforeEditing = title
                    }
                } onCommit: {
                    saveButtonEnabled = titleBeforeEditing != title
                }
            }
            
            Section(header: tagSectionHeaderView()) {
                List {
                    ForEach(self.tags, id: \.self) { tag in
                        TagLabel(title: tag)
                            .foregroundColor(.primary)
                    }
                }
                .frame(minHeight: bodyTextHeight * CGFloat(self.tags.count))
                .listStyle(PlainListStyle())
                .sheet(isPresented: $editTags) {
                    AddTagView(tags: $tags, isUpdate: true)
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(linkCollectorViewModel)
                }
            }
            
            Section(header: NoteLabel(title: "Note")) {
                TextEditor(text: $note)
                    .onChange(of: note, perform: { _ in
                        saveButtonEnabled = true
                    })
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.leading)
                    .border(Color.secondary)
                    .frame(minHeight: 150)
            }
        }
    }
    
    private func tagSectionHeaderView() -> some View {
        HStack {
            TagLabel(title: "Tags")
            
            Spacer()
            
            Button {
                originalTags.removeAll()
                originalTags.append(contentsOf: tags)
                editTags.toggle()
                saveButtonEnabled = true
            } label: {
                TagLabel(title: "Edit tags")
                    .foregroundColor(Color.blue)
            }
        }
    }
    
    private func editLinkButtons() -> some View {
        HStack {
            Button(action: {
                dismiss.callAsFunction()
            }, label: {
                Label("Cancel", systemImage: "chevron.backward")
            })
            .foregroundColor(Color.blue)
            
            Spacer()
            
            Text("Edit a link")
            
            Spacer()
            
            Button(action: {
                saveEntities()
                saveButtonClicked = true
                dismiss.callAsFunction()
            }, label: {
                Label("Save", systemImage: "square.and.arrow.down")
            })
            .disabled(!saveButtonEnabled)
            .foregroundColor(saveButtonEnabled ? Color.blue : Color.gray)
        }
    }
    
    private func saveEntities() -> Void {
        let linkDTO = LinkDTO(id: id, title: title, note: note)
        linkCollectorViewModel.linkDTO = linkDTO
        
        for tag in tags {
            linkCollectorViewModel.tagDTO = TagDTO(name: tag, link: linkDTO)
            
            if let index = originalTags.firstIndex(of: tag) {
                originalTags.remove(at: index)
            }
        }
        
        for tag in originalTags {
            linkCollectorViewModel.remove(tag: tag, from: linkDTO)
        }
    }
}

struct EditLinkView_Previews: PreviewProvider {
    @State static var saveButtonClicked = false
    static var previews: some View {
        EditLinkView(id: UUID(), title: "title", note: "note", tags: [String](), saveButtonClicked: $saveButtonClicked)
    }
}
