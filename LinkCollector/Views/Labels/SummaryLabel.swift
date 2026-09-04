//
//  SummaryLabel.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 9/4/26.
//

import SwiftUI

struct SummaryLabel: View {
    var title: String
    
    var body: some View {
        Label(title, systemImage: "text.append")
    }
}
