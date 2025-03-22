//
//  LinkePilerWidgetEntryView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/30/22.
//

import SwiftUI
import WidgetKit

struct WidgetEntryView : View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    private let backgroudImageName = "LinkPilerWidgetBackground"
    private let wideBackgroudImageName = "LinkPilerWidgetBackgroundWide"
    
    var entry: WidgetEntry
    
    private var widgetURL: URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = LinkPilerConstants.widgetURLScheme.rawValue
        urlComponents.path = "/\(entry.id)"
        urlComponents.query = "\(entry.title)"
        return urlComponents.url
    }

    private var futureDate: Date {
        let components = DateComponents(second: 75)
        let futureDate = Calendar.current.date(byAdding: components, to: Date())!
        return futureDate
    }
    
    var body: some View {
        ZStack {
            switch widgetFamily {
            case .systemSmall, .systemLarge:
                Image(backgroudImageName)
                    .resizable()
            case .systemMedium, .systemExtraLarge:
                Image(wideBackgroudImageName)
                    .resizable()
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                Image(backgroudImageName)
                    .resizable()
            @unknown default:
                Image(backgroudImageName)
                    .resizable()
            }
            
            VStack {
                Spacer(minLength: 16)
                
                HStack {
                    #if canImport(UIKit)
                    if let favicon = entry.favicon, let uiImage = UIImage(data: favicon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 32, maxHeight: 32)
                    }
                    #else
                    if let favicon = entry.favicon, let nsImage = NSImage(data: favicon) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 32, maxHeight: 32)
                    }
                    #endif
                    
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
