//
//  LinkePilerWidgetEntryView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/30/22.
//

import SwiftUI
import WidgetKit

struct WidgetEntryView : View {
    var entry: WidgetEntry
    
    private var widgetURL: URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme="widget-linkpiler"
        urlComponents.path="/\(entry.id)"
        urlComponents.query="\(entry.title)"
        
        return urlComponents.url
    }

    private var futureDate: Date {
        let components = DateComponents(second: 75)
        let futureDate = Calendar.current.date(byAdding: components, to: Date())!
        return futureDate
    }
    
    var body: some View {
        ZStack {
            Image("LinkPilerWidgetBackground")
                .resizable()
            
            VStack {
                Spacer(minLength: 16)
                
                HStack {
                    if let favicon = entry.favicon, let uiImage = UIImage(data: favicon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 32, maxHeight: 32)
                    }
                    
                    Text(entry.title)
                        .truncationMode(.tail)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white)
                }
                
                Spacer(minLength: 4)

                Text(entry.created, style: .date)
                    .font(.caption)
                    .foregroundColor(.mint)
            }
            .widgetURL(widgetURL)
            .padding()
        }
    }
}
