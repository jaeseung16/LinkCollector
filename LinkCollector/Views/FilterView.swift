//
//  FilterView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/8/25.
//

import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @Binding var selectedTags: Set<TagEntity>
    @Binding var dateInterval: DateInterval?
    @State var start: Date
    @State var end: Date
    
    private var filteredTags: [TagEntity] {
        viewModel.tags.filter { !selectedTags.contains($0) }
    }
    
    var body: some View {
        VStack {
            header()

            Form {
                Section {
                    DatePicker("From", selection: $start, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                    DatePicker(selection: $end, in: start..., displayedComponents: [.date]) {
                        Text("To")
                    }
                } header: {
                    Text("Filter by Date Range")
                }
                
                Section {
                    Text("SELECTED")
                        .font(.caption)
                    
                    List {
                        ForEach(Array(selectedTags), id: \.id) { tag in
                            Button {
                                selectedTags.remove(tag)
                            } label: {
                                tagInfo(for: tag)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Text("TAGS")
                        .font(.caption)
                    
                    ForEach(filteredTags, id: \.id) { tag in
                        Button {
                            selectedTags.insert(tag)
                        } label: {
                            tagInfo(for: tag)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Filter By Tags")
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding()
    }
    
    private func header() -> some View {
        HStack {
            Button {
                let startDate = Calendar.current.startOfDay(for: start)
                let endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end)!
                
                dateInterval = DateInterval(start: startDate, end: endDate)
                
                dismiss.callAsFunction()
            } label: {
                Text("Done")
            }
            
            Spacer()
            
            Button {
                dateInterval = nil
                selectedTags.removeAll()
                dismiss.callAsFunction()
            } label: {
                Text("Reset")
            }
        }
    }
    
    private func tagInfo(for tag: TagEntity) -> some View {
        HStack {
            Label(tag.name ?? "", systemImage: "tag")
            Spacer()
            Text("\(tag.links?.count ?? 0)")
        }
    }
}
