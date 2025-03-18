//
//  LinkLabel.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 5/9/22.
//

import SwiftUI

struct LinkLabel: View {
    var link: LinkEntity
    
    var body: some View {
        HStack {
            Text(link.title ?? "No title")
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            VStack {
                if let favicon = link.favicon, let uiImage = UIImage(data: favicon) {
                    Spacer()
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 24, maxHeight: 24)
                }
                
                Spacer()
                
                Text(link.created!, format: Date.FormatStyle(date: .numeric, time: .omitted))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
}
