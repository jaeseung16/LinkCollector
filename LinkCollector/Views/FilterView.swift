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
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                header()
                
                #if canImport(AppKit)
                Divider()
                #endif
                
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
                    
                    #if canImport(AppKit)
                    Divider()
                    #endif
                    
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
                        #if canImport(AppKit)
                        .frame(maxHeight: bodyTextHeight * CGFloat(selectedTags.count))
                        #endif
                        
                        Text("TAGS")
                            .font(.caption)
                        
                        List {
                            ForEach(filteredTags, id: \.id) { tag in
                                Button {
                                    selectedTags.insert(tag)
                                } label: {
                                    tagInfo(for: tag)
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        #if canImport(AppKit)
                        .frame(maxHeight: bodyTextHeight * CGFloat(filteredTags.count))
                        #endif
                    } header: {
                        Text("Filter By Tags")
                    }
                }
            }
            #if canImport(UIKit)
            .frame(maxHeight: .infinity, alignment: .top)
            #endif
            .padding()
        }
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
