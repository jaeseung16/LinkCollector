//
//  DateRangePickerView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 5/11/22.
//

import SwiftUI

struct DateRangePickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    @State var start: Date
    @State var end: Date
    
    var body: some View {
        VStack {
            header()
            Divider()
            DatePicker("From", selection: $start, displayedComponents: [.date])
                .datePickerStyle(.compact)
            DatePicker(selection: $end, in: start..., displayedComponents: [.date]) {
                Text("To")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding()
    }
    
    private func header() -> some View {
        VStack {
            Text("Select Date Range")
            HStack {
                Button {
                    let startDate = Calendar.current.startOfDay(for: start)
                    let endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end)!
                    
                    viewModel.dateInterval = DateInterval(start: startDate, end: endDate)
                    
                    dismiss.callAsFunction()
                } label: {
                    Text("Done")
                }
                
                Spacer()
                
                Button {
                    viewModel.dateInterval = nil
                    dismiss.callAsFunction()
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}

